import 'dart:math';
import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/appwrite_client.dart';
import '../../../app/constants/app_constants.dart';
import '../../../core/utils/row_helpers.dart';
import '../domain/group_model.dart';
import '../domain/group_member_model.dart';
import '../../auth/data/auth_repository.dart';

import '../../../core/local_db/database_helper.dart';
import '../../../core/services/sync_service.dart';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sqflite/sqflite.dart';

class GroupRepository {
  final TablesDB _tablesDB;
  final DatabaseHelper _dbHelper;
  final SyncService _syncService;

  GroupRepository(this._tablesDB, this._dbHelper, this._syncService);

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

    if (kIsWeb) {
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
    } else {
      final db = await _dbHelper.database;
      
      // Save locally
      await db.insert('groups', {'id': groupId, ...groupData});
      await db.insert('group_members', {'id': memberId, ...memberData});

      // Queue sync
      await _syncService.queueAction('create', 'groups', groupData, documentId: groupId);
      await _syncService.queueAction('create', 'group_members', memberData, documentId: memberId);

      return Group.fromMap({'\$id': groupId, ...groupData});
    }
  }

  Future<void> joinGroup(String joinCode, String userId) async {
    // 1. Find the group by join code (require network for safety, or search local if we sync all groups? Appwrite groups can't be fetched if we are not members. So joining requires network)
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

    if (!kIsWeb) {
      final db = await _dbHelper.database;
      await db.insert('group_members', {'id': memberId, ...memberData});
      
      final group = Group.fromMap(groups.rows.first.dataWithId);
      final groupDataToInsert = group.toMap();
      groupDataToInsert['id'] = group.id;
      await db.insert('groups', groupDataToInsert, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<List<Group>> getUserGroups(String userId) async {
    if (kIsWeb) {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none)) {
        throw Exception('No internet connection.');
      }
      return _fetchUserGroupsRemote(userId);
    } else {
      // 1. Fetch from local DB
      final db = await _dbHelper.database;
      var memberships = await db.query(
        'group_members',
        where: 'userId = ?',
        whereArgs: [userId],
      );

      if (memberships.isEmpty) {
        // First time load or empty: wait for sync
        await _syncUserGroupsFromRemote(userId);
        memberships = await db.query(
          'group_members',
          where: 'userId = ?',
          whereArgs: [userId],
        );
      } else {
        // Already have local data: sync in background
        _syncUserGroupsFromRemote(userId);
      }

      if (memberships.isEmpty) return [];

      final groupIds = memberships.map((m) => m['groupId'] as String).toList();
      if (groupIds.isEmpty) return [];

      final placeholders = List.filled(groupIds.length, '?').join(',');
      final groups = await db.query(
        'groups',
        where: 'id IN ($placeholders)',
        whereArgs: groupIds,
      );

      return groups.map((m) {
        final data = Map<String, dynamic>.from(m);
        data['\$id'] = data['id'];
        return Group.fromMap(data);
      }).toList();
    }
  }

  Future<void> _syncUserGroupsFromRemote(String userId) async {
    try {
      final remoteGroups = await _fetchUserGroupsRemote(userId);
      final db = await _dbHelper.database;
      
      // We also need to fetch the memberships so we can sync them locally
      final memberships = await _tablesDB.listRows(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.groupMembersCollection,
        queries: [Query.equal('userId', userId)],
      );

      for (final doc in memberships.rows) {
        final member = GroupMember.fromMap(doc.dataWithId);
        final data = member.toMap();
        data['id'] = member.id;
        await db.insert('group_members', data, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      for (final group in remoteGroups) {
        final data = group.toMap();
        data['id'] = group.id;
        await db.insert('groups', data, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    } catch (_) {
      // Ignore network errors during background sync
    }
  }

  Future<List<Group>> _fetchUserGroupsRemote(String userId) async {
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
    if (kIsWeb) {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none)) {
        throw Exception('No internet connection.');
      }
      return _fetchGroupMembersRemote(groupId);
    } else {
      // 1. Fetch from local DB
      final db = await _dbHelper.database;
      var memberships = await db.query(
        'group_members',
        where: 'groupId = ?',
        whereArgs: [groupId],
      );

      if (memberships.isEmpty) {
        // Wait for sync if empty
        await _syncGroupMembersFromRemote(groupId);
        memberships = await db.query(
          'group_members',
          where: 'groupId = ?',
          whereArgs: [groupId],
        );
      } else {
        // Sync in background
        _syncGroupMembersFromRemote(groupId);
      }

      return memberships.map((m) {
        final data = Map<String, dynamic>.from(m);
        data['\$id'] = data['id'];
        return GroupMember.fromMap(data);
      }).toList();
    }
  }

  Future<void> _syncGroupMembersFromRemote(String groupId) async {
    try {
      final members = await _fetchGroupMembersRemote(groupId);
      final db = await _dbHelper.database;
      for (final member in members) {
        final data = member.toMap();
        data['id'] = member.id;
        await db.insert('group_members', data, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    } catch (_) {
      // Ignore network errors
    }
  }

  Future<List<GroupMember>> _fetchGroupMembersRemote(String groupId) async {
    final res = await _tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.groupMembersCollection,
      queries: [Query.equal('groupId', groupId)],
    );
    return res.rows.map((d) => GroupMember.fromMap(d.dataWithId)).toList();
  }

  Future<void> leaveGroup(String groupId, String userId) async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      throw Exception('Leaving a group requires an active internet connection.');
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

      if (!kIsWeb) {
        final db = await _dbHelper.database;
        await db.delete('group_members', where: 'id = ?', whereArgs: [docId]);
      }
    }
  }

  Future<void> deleteGroup(String groupId) async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      throw Exception('Deleting a group requires an active internet connection.');
    }
    final members = await _fetchGroupMembersRemote(groupId);
    for (final member in members) {
      await _tablesDB.deleteRow(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.groupMembersCollection,
        rowId: member.id,
      );
      if (!kIsWeb) {
        final db = await _dbHelper.database;
        await db.delete('group_members', where: 'id = ?', whereArgs: [member.id]);
      }
    }
    await _tablesDB.deleteRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.groupsCollection,
      rowId: groupId,
    );
    if (!kIsWeb) {
      final db = await _dbHelper.database;
      await db.delete('groups', where: 'id = ?', whereArgs: [groupId]);
    }
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
  return GroupRepository(
    ref.watch(appwriteTablesDBProvider),
    ref.watch(databaseHelperProvider),
    ref.watch(syncServiceProvider),
  );
});

final userGroupsProvider = FutureProvider<List<Group>>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return [];
  return ref.watch(groupRepositoryProvider).getUserGroups(user.id);
});
