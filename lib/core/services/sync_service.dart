import 'dart:convert';
import 'package:appwrite/appwrite.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/constants/app_constants.dart';
import '../local_db/database_helper.dart';
import '../appwrite_client.dart';

final syncServiceProvider = Provider<SyncService>((ref) {
  final tablesDB = ref.watch(appwriteTablesDBProvider);
  final dbHelper = ref.watch(databaseHelperProvider);
  return SyncService(tablesDB, dbHelper);
});

class SyncService {
  final TablesDB _tablesDB;
  final DatabaseHelper _dbHelper;
  bool _isSyncing = false;

  SyncService(this._tablesDB, this._dbHelper) {
    if (!kIsWeb) {
      _initConnectivityListener();
    }
  }

  void _initConnectivityListener() {
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (!results.contains(ConnectivityResult.none)) {
        syncPendingItems();
      }
    });
  }

  Future<void> syncPendingItems() async {
    if (kIsWeb) return;
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final db = await _dbHelper.database;
      final queue = await db.query('sync_queue', orderBy: 'id ASC');

      for (final item in queue) {
        final id = item['id'] as int;
        final action = item['action'] as String;
        final collectionName = item['collectionName'] as String;
        final documentId = item['documentId'] as String?;
        final payloadStr = item['payload'] as String?;

        try {
          String targetTableId;
          if (collectionName == 'expenses') {
            targetTableId = AppConstants.expensesCollection;
          } else if (collectionName == 'groups') {
            targetTableId = AppConstants.groupsCollection;
          } else if (collectionName == 'group_members') {
            targetTableId = AppConstants.groupMembersCollection;
          } else if (collectionName == 'settlements') {
            targetTableId = AppConstants.settlementsCollection;
          } else {
            targetTableId = collectionName;
          }

          if (action == 'create' && payloadStr != null) {
            final payload = jsonDecode(payloadStr) as Map<String, dynamic>;
            await _tablesDB.createRow(
              databaseId: AppConstants.databaseId,
              tableId: targetTableId,
              rowId: documentId ?? ID.unique(),
              data: payload,
            );
          } else if (action == 'update' && payloadStr != null && documentId != null) {
            final payload = jsonDecode(payloadStr) as Map<String, dynamic>;
            await _tablesDB.updateRow(
              databaseId: AppConstants.databaseId,
              tableId: targetTableId,
              rowId: documentId,
              data: payload,
            );
          } else if (action == 'delete' && documentId != null) {
            await _tablesDB.deleteRow(
              databaseId: AppConstants.databaseId,
              tableId: targetTableId,
              rowId: documentId,
            );
          }
          
          // On success, remove from queue
          await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
        } catch (e) {
          debugPrint('Sync Error on item $id: $e');
          // If it's not a network error, maybe remove it so we don't get stuck?
          // For now, let it retry on next network connection
        }
      }
    } catch (e) {
      debugPrint('Sync process failed: $e');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> queueAction(String action, String collectionName, Map<String, dynamic>? payload, {String? documentId}) async {
    if (kIsWeb) return;
    final db = await _dbHelper.database;
    await db.insert('sync_queue', {
      'collectionName': collectionName,
      'documentId': documentId,
      'action': action,
      'payload': payload != null ? jsonEncode(payload) : null,
      'createdAt': DateTime.now().toIso8601String(),
    });
    
    // Try syncing immediately in case we have internet
    syncPendingItems();
  }
}
