import 'dart:convert';
import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/appwrite_client.dart';
import '../../../app/constants/app_constants.dart';
import '../../../core/utils/row_helpers.dart';
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
    // 1. Create a settlement record
    await _tablesDB.createRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.settlementsCollection,
      rowId: ID.unique(),
      data: {
        'groupId': groupId,
        'fromUserId': fromUserId,
        'toUserId': toUserId,
        'amount': amount,
        'settledExpenseIds': expenseIds,
        'createdAt': DateTime.now().toIso8601String(),
      },
    );

    // 2. Mark expenses as settled
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
