import 'dart:convert';
import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../core/appwrite_client.dart';
import '../../../core/utils/row_helpers.dart';
import '../../../app/constants/app_constants.dart';
import '../../auth/data/auth_repository.dart';
import '../../expenses/data/expense_repository.dart';
import '../../groups/data/group_repository.dart';
import '../../profile/domain/profile_model.dart';
import '../../expenses/domain/expense_split_model.dart';
import '../domain/settlement_model.dart';

enum CashFlowType { expense, settlementPaid, settlementReceived }

class CashFlowActivityItem {
  final String id;
  final CashFlowType type;
  final String title;
  final String? subtitle;
  final String? groupName;
  final double amount;
  final DateTime date;
  final String? category;
  final String? payerName;
  final dynamic originalObject;

  CashFlowActivityItem({
    required this.id,
    required this.type,
    required this.title,
    this.subtitle,
    this.groupName,
    required this.amount,
    required this.date,
    this.category,
    this.payerName,
    this.originalObject,
  });
}

class CashFlowSummaryData {
  final double totalSpent;
  final double personalSpent;
  final double groupShareSpent;
  final double totalReceived;
  final double totalPaidOut;
  final double netCashFlow;
  final List<CashFlowActivityItem> activities;
  final List<Settlement> settlementsReceived;
  final List<Settlement> settlementsPaid;

  CashFlowSummaryData({
    required this.totalSpent,
    required this.personalSpent,
    required this.groupShareSpent,
    required this.totalReceived,
    required this.totalPaidOut,
    required this.netCashFlow,
    required this.activities,
    required this.settlementsReceived,
    required this.settlementsPaid,
  });

  factory CashFlowSummaryData.empty() => CashFlowSummaryData(
        totalSpent: 0,
        personalSpent: 0,
        groupShareSpent: 0,
        totalReceived: 0,
        totalPaidOut: 0,
        netCashFlow: 0,
        activities: [],
        settlementsReceived: [],
        settlementsPaid: [],
      );
}

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

    // Check if any of the referenced expenses are now fully settled by all debtors
    for (final expId in expenseIds) {
      try {
        final splitsRes = await _tablesDB.listRows(
          databaseId: AppConstants.databaseId,
          tableId: AppConstants.expenseSplitsCollection,
          queries: [Query.equal('expenseId', expId)],
        );
        final splits = splitsRes.rows.map((d) => ExpenseSplit.fromMap(d.dataWithId)).toList();

        final expDoc = await _tablesDB.getRow(
          databaseId: AppConstants.databaseId,
          tableId: AppConstants.expensesCollection,
          rowId: expId,
        );
        final payerUserId = expDoc.data['userId'];

        final otherSplits = splits.where((s) => s.userId != payerUserId && s.isIncluded).toList();
        final totalOwedByOthers = otherSplits.fold<double>(0.0, (sum, s) => sum + s.amountOwed);

        // Find all settlements referencing this expense in the group
        final setRes = await _tablesDB.listRows(
          databaseId: AppConstants.databaseId,
          tableId: AppConstants.settlementsCollection,
          queries: [Query.equal('groupId', groupId)],
        );
        final allGroupSettlements = setRes.rows.map((d) => Settlement.fromMap(d.dataWithId)).toList();
        final expSettlements = allGroupSettlements.where((s) => s.settledExpenseIds.contains(expId)).toList();
        final totalSettledAmount = expSettlements.fold<double>(0.0, (sum, s) => sum + s.amount);

        if (totalSettledAmount >= totalOwedByOthers - 0.05) {
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
      } catch (_) {}
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

  Future<List<Settlement>> getUserSettlements(String userId) async {
    try {
      final resPaid = await _tablesDB.listRows(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.settlementsCollection,
        queries: [Query.equal('fromUserId', userId), Query.orderDesc('createdAt')],
      );
      final resReceived = await _tablesDB.listRows(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.settlementsCollection,
        queries: [Query.equal('toUserId', userId), Query.orderDesc('createdAt')],
      );

      final Map<String, Settlement> all = {};
      for (final r in resPaid.rows) {
        all[r.$id] = Settlement.fromMap(r.dataWithId);
      }
      for (final r in resReceived.rows) {
        all[r.$id] = Settlement.fromMap(r.dataWithId);
      }

      final list = all.values.toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (_) {
      return [];
    }
  }
}

final settlementRepositoryProvider = Provider<SettlementRepository>((ref) {
  return SettlementRepository(
    ref.watch(appwriteTablesDBProvider),
    ref.watch(appwriteFunctionsProvider),
  );
});

final userCashFlowProvider = FutureProvider.family<CashFlowSummaryData, DateTime>((ref, month) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return CashFlowSummaryData.empty();

  final myUserId = user.id;

  // 1. Fetch monthly expenses
  final expenses = await ref.watch(monthlyExpensesProvider(month).future);

  // 2. Fetch splits
  final userSplits = ref.watch(userSplitsProvider).valueOrNull ?? [];
  final splitMap = {for (var s in userSplits) s.expenseId: s.amountOwed};

  // 3. Fetch groups & profiles for names
  final groups = ref.watch(userGroupsProvider).valueOrNull ?? [];
  final groupMap = {for (var g in groups) g.id: g.name};

  // 4. Fetch user settlements
  final settlementsRepo = ref.watch(settlementRepositoryProvider);
  final allSettlements = await settlementsRepo.getUserSettlements(myUserId);

  // Filter settlements for this month
  final monthSettlements = allSettlements.where((s) {
    return s.createdAt.year == month.year && s.createdAt.month == month.month;
  }).toList();

  final settlementsReceived = monthSettlements.where((s) => s.toUserId == myUserId).toList();
  final settlementsPaid = monthSettlements.where((s) => s.fromUserId == myUserId).toList();

  // Fetch profiles of participants in settlements & expenses for display names
  final participantIds = <String>{};
  for (final s in monthSettlements) {
    participantIds.add(s.fromUserId);
    participantIds.add(s.toUserId);
  }
  for (final e in expenses) {
    if (e.userId.isNotEmpty) {
      participantIds.add(e.userId);
    }
  }

  Map<String, String> profileNames = {};
  if (participantIds.isNotEmpty) {
    try {
      final tablesDB = ref.watch(appwriteTablesDBProvider);
      final resProfiles = await tablesDB.listRows(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.profilesCollection,
        queries: [Query.equal('userId', participantIds.toList())],
      );
      final profiles = resProfiles.rows.map((d) => Profile.fromMap(d.dataWithId)).toList();
      profileNames = {for (var p in profiles) p.userId: p.fullName};
    } catch (_) {}
  }

  // Calculate expense spending
  double personalSpent = 0.0;
  double groupShareSpent = 0.0;

  final List<CashFlowActivityItem> activities = [];

  for (final e in expenses) {
    final isPersonal = e.groupId == null || e.groupId!.isEmpty;
    final isMine = e.userId == myUserId;
    final payerName = isMine ? 'You' : (profileNames[e.userId] ?? 'Member');

    if (isPersonal && isMine) {
      personalSpent += e.amount;
      activities.add(
        CashFlowActivityItem(
          id: e.id,
          type: CashFlowType.expense,
          title: e.description,
          subtitle: 'Personal Expense',
          groupName: 'Personal',
          amount: e.amount,
          date: e.expenseDate,
          category: e.category,
          payerName: 'You',
          originalObject: e,
        ),
      );
    } else if (!isPersonal) {
      final myShare = splitMap[e.id] ?? (isMine ? e.amount : 0.0);
      if (myShare > 0) {
        groupShareSpent += myShare;
        activities.add(
          CashFlowActivityItem(
            id: e.id,
            type: CashFlowType.expense,
            title: e.description,
            subtitle: 'Group Expense (Share: ₹${myShare.toStringAsFixed(0)})',
            groupName: groupMap[e.groupId] ?? 'Group',
            amount: myShare,
            date: e.expenseDate,
            category: e.category,
            payerName: payerName,
            originalObject: e,
          ),
        );
      }
    }
  }

  // Add Settlements Received
  double totalReceived = 0.0;
  for (final s in settlementsReceived) {
    totalReceived += s.amount;
    final fromName = profileNames[s.fromUserId] ?? 'Group Member';
    activities.add(
      CashFlowActivityItem(
        id: s.id,
        type: CashFlowType.settlementReceived,
        title: 'Received from $fromName',
        subtitle: 'Settlement Payment',
        groupName: groupMap[s.groupId] ?? 'Group',
        amount: s.amount,
        date: s.createdAt,
        category: 'settled',
        payerName: fromName,
        originalObject: s,
      ),
    );
  }

  // Add Settlements Paid
  double totalPaidOut = 0.0;
  for (final s in settlementsPaid) {
    totalPaidOut += s.amount;
    final toName = profileNames[s.toUserId] ?? 'Group Member';
    activities.add(
      CashFlowActivityItem(
        id: s.id,
        type: CashFlowType.settlementPaid,
        title: 'Paid to $toName',
        subtitle: 'Settlement Payment',
        groupName: groupMap[s.groupId] ?? 'Group',
        amount: s.amount,
        date: s.createdAt,
        category: 'settled',
        payerName: 'You',
        originalObject: s,
      ),
    );
  }

  // Sort activities newest first
  activities.sort((a, b) => b.date.compareTo(a.date));

  final totalSpent = personalSpent + groupShareSpent;
  // Net cash flow = Received - (Spent + PaidOut)
  final netCashFlow = totalReceived - (totalSpent + totalPaidOut);

  return CashFlowSummaryData(
    totalSpent: totalSpent,
    personalSpent: personalSpent,
    groupShareSpent: groupShareSpent,
    totalReceived: totalReceived,
    totalPaidOut: totalPaidOut,
    netCashFlow: netCashFlow,
    activities: activities,
    settlementsReceived: settlementsReceived,
    settlementsPaid: settlementsPaid,
  );
});
