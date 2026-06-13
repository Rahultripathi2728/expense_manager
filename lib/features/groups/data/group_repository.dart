import 'dart:math';
import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/appwrite_client.dart';
import '../../../app/constants/app_constants.dart';
import '../../../core/utils/row_helpers.dart';
import '../domain/group_model.dart';
import '../domain/group_member_model.dart';
import '../../auth/data/auth_repository.dart';

class GroupRepository {
  final TablesDB _tablesDB;

  GroupRepository(this._tablesDB);

  Future<Group> createGroup(String name, String userId) async {
    final joinCode = ID.custom(_generateJoinCode());
    final group = await _tablesDB.createRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.groupsCollection,
      rowId: ID.unique(),
      data: {
        'name': name,
        'joinCode': joinCode,
        'createdBy': userId,
        'createdAt': DateTime.now().toIso8601String(),
      },
    );

    await _tablesDB.createRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.groupMembersCollection,
      rowId: ID.unique(),
      data: {
        'groupId': group.$id,
        'userId': userId,
        'role': 'admin',
        'joinedAt': DateTime.now().toIso8601String(),
      },
    );

    return Group.fromMap(group.dataWithId);
  }

  Future<void> joinGroup(String joinCode, String userId) async {
    // 1. Find the group by join code
    final groups = await _tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.groupsCollection,
      queries: [Query.equal('joinCode', joinCode)],
    );

    if (groups.rows.isEmpty) {
      throw Exception('Group not found');
    }

    final groupId = groups.rows.first.dataWithId['\$id'];

    // 2. Check if already a member
    final memberships = await _tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.groupMembersCollection,
      queries: [Query.equal('groupId', groupId), Query.equal('userId', userId)],
    );

    if (memberships.rows.isNotEmpty) {
      throw Exception('Already a member of this group');
    }

    // 3. Add to group members
    await _tablesDB.createRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.groupMembersCollection,
      rowId: ID.unique(),
      data: {
        'groupId': groupId,
        'userId': userId,
        'role': 'member',
        'joinedAt': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<List<Group>> getUserGroups(String userId) async {
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
    final res = await _tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.groupMembersCollection,
      queries: [Query.equal('groupId', groupId)],
    );
    return res.rows.map((d) => GroupMember.fromMap(d.dataWithId)).toList();
  }

  Future<void> leaveGroup(String groupId, String userId) async {
    final memberships = await _tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.groupMembersCollection,
      queries: [Query.equal('groupId', groupId), Query.equal('userId', userId)],
    );
    if (memberships.rows.isNotEmpty) {
      await _tablesDB.deleteRow(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.groupMembersCollection,
        rowId: memberships.rows.first.$id,
      );
    }
  }

  Future<void> deleteGroup(String groupId) async {
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

  static final _random = Random.secure();
  static const _chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  String _generateJoinCode() {
    return List.generate(
      AppConstants.joinCodeLength,
      (_) => _chars[_random.nextInt(_chars.length)],
    ).join();
  }
}

final groupRepositoryProvider = Provider<GroupRepository>((ref) {
  return GroupRepository(ref.watch(appwriteTablesDBProvider));
});

final userGroupsProvider = FutureProvider<List<Group>>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return [];
  return ref.watch(groupRepositoryProvider).getUserGroups(user.id);
});
