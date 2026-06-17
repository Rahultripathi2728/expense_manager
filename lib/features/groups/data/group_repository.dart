import 'dart:math';
import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/appwrite_client.dart';
import '../../../core/utils/row_helpers.dart';
import '../../../app/constants/app_constants.dart';
import '../domain/group_model.dart';
import '../domain/group_member_model.dart';
import '../../auth/data/auth_repository.dart';

import 'package:connectivity_plus/connectivity_plus.dart';

class GroupRepository {
  final TablesDB _tablesDB;

  GroupRepository(this._tablesDB);

  Future<Group> createGroup(String name, String userId) async {
    final joinCode = ID.custom(_generateJoinCode());
    final groupId = ID.unique();
    final groupData = {
      'name': name,
      'joinCode': joinCode,
      'createdBy': userId,
      'createdAt': DateTime.now().toIso8601String(),
    };
    final memberId = ID.unique();
    final memberData = {
      'groupId': groupId,
      'userId': userId,
      'role': 'admin',
      'joinedAt': DateTime.now().toIso8601String(),
    };

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      throw Exception('No internet connection.');
    }
    
    final group = await _tablesDB.createRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.groupsCollection,
      rowId: groupId,
      data: groupData,
    );

    await _tablesDB.createRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.groupMembersCollection,
      rowId: memberId,
      data: memberData,
    );
    return Group.fromMap(group.dataWithId);
  }

  Future<void> joinGroup(String joinCode, String userId) async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      throw Exception('Joining a group requires an active internet connection.');
    }

    final groups = await _tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.groupsCollection,
      queries: [Query.equal('joinCode', joinCode)],
    );

    if (groups.rows.isEmpty) {
      throw Exception('Group not found');
    }

    final groupId = groups.rows.first.dataWithId['\$id'];

    // Check if already a member
    final memberships = await _tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.groupMembersCollection,
      queries: [Query.equal('groupId', groupId), Query.equal('userId', userId)],
    );

    if (memberships.rows.isNotEmpty) {
      throw Exception('You are already a member of this group.');
    }

    // Join
    final memberId = ID.unique();
    final memberData = {
      'groupId': groupId,
      'userId': userId,
      'role': 'member',
      'joinedAt': DateTime.now().toIso8601String(),
    };

    await _tablesDB.createRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.groupMembersCollection,
      rowId: memberId,
      data: memberData,
    );
  }

  Future<List<Group>> getUserGroups(String userId) async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      throw Exception('No internet connection.');
    }
    
    final memberships = await _tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.groupMembersCollection,
      queries: [Query.equal('userId', userId)],
    );

    if (memberships.rows.isEmpty) return [];

    final groupIds = memberships.rows.map((d) => d.data['groupId']).toList();

    final groups = await _tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.groupsCollection,
      queries: [Query.equal('\$id', groupIds)],
    );

    return groups.rows.map((d) => Group.fromMap(d.dataWithId)).toList();
  }

  Future<List<GroupMember>> getGroupMembers(String groupId) async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      throw Exception('No internet connection.');
    }
    
    final memberships = await _tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.groupMembersCollection,
      queries: [Query.equal('groupId', groupId)],
    );

    return memberships.rows.map((d) => GroupMember.fromMap(d.dataWithId)).toList();
  }

  Future<void> leaveGroup(String groupId, String userId) async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      throw Exception('No internet connection.');
    }
    
    final memberships = await _tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.groupMembersCollection,
      queries: [Query.equal('groupId', groupId), Query.equal('userId', userId)],
    );
    if (memberships.rows.isNotEmpty) {
      final docId = memberships.rows.first.$id;
      await _tablesDB.deleteRow(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.groupMembersCollection,
        rowId: docId,
      );
    }
  }

  Future<void> deleteGroup(String groupId) async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      throw Exception('No internet connection.');
    }
    
    final members = await getGroupMembers(groupId);
    for (final member in members) {
      await _tablesDB.deleteRow(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.groupMembersCollection,
        rowId: member.id,
      );
    }
    await _tablesDB.deleteRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.groupsCollection,
      rowId: groupId,
    );
  }

  Future<void> transferOwnership(String groupId, String newOwnerId) async {
    final memberships = await _tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.groupMembersCollection,
      queries: [
        Query.equal('groupId', groupId),
        Query.equal('userId', newOwnerId),
      ],
    );
    if (memberships.rows.isNotEmpty) {
      await _tablesDB.updateRow(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.groupMembersCollection,
        rowId: memberships.rows.first.$id,
        data: {'role': 'admin'},
      );
    }
  }

  String _generateJoinCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(Iterable.generate(
        6, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }
}

final groupRepositoryProvider = Provider<GroupRepository>((ref) {
  return GroupRepository(
    ref.watch(appwriteTablesDBProvider),
  );
});

final userGroupsProvider = FutureProvider<List<Group>>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return [];
  return ref.watch(groupRepositoryProvider).getUserGroups(user.id);
});

final groupMembersProvider = FutureProvider.family<List<GroupMember>, String>((ref, groupId) async {
  return ref.watch(groupRepositoryProvider).getGroupMembers(groupId);
});
