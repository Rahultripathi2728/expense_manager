import 'dart:convert';
import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../core/appwrite_client.dart';
import '../../../core/utils/row_helpers.dart';
import '../../../app/constants/app_constants.dart';
import '../domain/settlement_model.dart';

class SettlementRepository {
  final TablesDB _tablesDB;
  final Functions _functions;

  SettlementRepository(this._tablesDB, this._functions);

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
  }

  Future<List<Settlement>> getGroupSettlements(String groupId) async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      throw Exception('No internet connection.');
    }
    return _fetchSettlementsRemote(groupId);
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
  );
});
