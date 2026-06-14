import 'dart:convert';
import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/appwrite_client.dart';
import '../../../app/constants/app_constants.dart';
import '../../../core/utils/row_helpers.dart';
import '../../../core/local_db/database_helper.dart';
import '../../../core/services/sync_service.dart';
import '../domain/settlement_model.dart';

class SettlementRepository {
  final TablesDB _tablesDB;
  final Functions _functions;
  final DatabaseHelper _dbHelper;
  final SyncService _syncService;

  SettlementRepository(this._tablesDB, this._functions, this._dbHelper, this._syncService);

  Future<void> settleBalances(
    String groupId,
    String fromUserId,
    String toUserId,
    double amount,
  ) async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      throw Exception('Settling balances requires an active internet connection.');
    }
    await _functions.createExecution(
      functionId: AppConstants.settleBalancesFunction,
      body: jsonEncode({
        'groupId': groupId,
        'fromUserId': fromUserId,
        'toUserId': toUserId,
        'amount': amount,
      }),
    );
  }

  Future<void> settleBalancesLocalFallback(
    String groupId,
    String fromUserId,
    String toUserId,
    double amount,
    List<String> expenseIds,
  ) async {
    final settlementId = ID.unique();
    final data = {
      'groupId': groupId,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'amount': amount,
      'settledExpenseIds': expenseIds,
      'createdAt': DateTime.now().toIso8601String(),
    };

    if (kIsWeb) {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none)) {
        throw Exception('Settling balances requires an active internet connection.');
      }
      await _tablesDB.createRow(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.settlementsCollection,
        rowId: settlementId,
        data: data,
      );

      for (final expId in expenseIds) {
        await _tablesDB.updateRow(
          databaseId: AppConstants.databaseId,
          tableId: AppConstants.expensesCollection,
          rowId: expId,
          data: {
            'isSettled': true,
            'settledAt': DateTime.now().toIso8601String(),
          },
        );
      }
    } else {
      final db = await _dbHelper.database;
      
      // 1. Save settlement locally
      final localData = Map<String, dynamic>.from(data);
      localData['settledExpenseIds'] = jsonEncode(expenseIds);
      await db.insert('settlements', {'id': settlementId, ...localData});
      
      // 2. Queue settlement creation
      await _syncService.queueAction('create', 'settlements', data, documentId: settlementId);

      // 3. Mark expenses as settled locally and queue updates
      for (final expId in expenseIds) {
        final updateData = {
          'isSettled': 1,
          'settledAt': DateTime.now().toIso8601String(),
        };
        await db.update('expenses', updateData, where: 'id = ?', whereArgs: [expId]);
        await _syncService.queueAction('update', 'expenses', {'isSettled': true, 'settledAt': updateData['settledAt']}, documentId: expId);
      }
    }
  }

  Future<List<Settlement>> getGroupSettlements(String groupId) async {
    if (kIsWeb) {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none)) {
        throw Exception('No internet connection.');
      }
      return _fetchSettlementsRemote(groupId);
    } else {
      // 1. Sync in background
      _syncSettlementsFromRemote(groupId);

      // 2. Fetch from local DB
      final db = await _dbHelper.database;
      final settlements = await db.query(
        'settlements',
        where: 'groupId = ?',
        whereArgs: [groupId],
        orderBy: 'createdAt DESC',
      );

      return settlements.map((m) {
        final data = Map<String, dynamic>.from(m);
        data['\$id'] = data['id'];
        if (data['settledExpenseIds'] is String) {
          data['settledExpenseIds'] = List<String>.from(jsonDecode(data['settledExpenseIds']));
        }
        return Settlement.fromMap(data);
      }).toList();
    }
  }

  Future<void> _syncSettlementsFromRemote(String groupId) async {
    try {
      final settlements = await _fetchSettlementsRemote(groupId);
      final db = await _dbHelper.database;
      for (final settlement in settlements) {
        final data = settlement.toMap();
        data['id'] = settlement.id;
        data['settledExpenseIds'] = jsonEncode(data['settledExpenseIds']);
        await db.insert('settlements', data, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    } catch (_) {
      // Ignore network errors
    }
  }

  Future<List<Settlement>> _fetchSettlementsRemote(String groupId) async {
    final res = await _tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.settlementsCollection,
      queries: [Query.equal('groupId', groupId), Query.orderDesc('createdAt')],
    );
    return res.rows.map((d) => Settlement.fromMap(d.dataWithId)).toList();
  }
}

final settlementRepositoryProvider = Provider<SettlementRepository>((ref) {
  return SettlementRepository(
    ref.watch(appwriteTablesDBProvider),
    ref.watch(appwriteFunctionsProvider),
    ref.watch(databaseHelperProvider),
    ref.watch(syncServiceProvider),
  );
});
