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
import '../../expenses/domain/expense_model.dart';
import '../../expenses/domain/expense_split_model.dart';
import '../domain/settlement_model.dart';
import '../domain/balance_calculator.dart';

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
  final double totalBillAmount;
  final double myShareAmount;
  final bool isPaidByMe;

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
    this.totalBillAmount = 0.0,
    this.myShareAmount = 0.0,
    this.isPaidByMe = false,
  });
}

class CashFlowSummaryData {
  final double totalSpent; // Net consumption (Personal + My Share) for budget tracking
  final double totalOutOfPocketPaid; // Actual cash paid by user (Bills paid + Settlements paid)
  final double personalSpent;
  final double groupShareSpent;
  final double totalReceived; // Settlements received from friends
  final double totalPaidOut; // Settlements paid out to friends
  final double netCashFlow; // Inflow vs Outflow
  final List<CashFlowActivityItem> activities;
  final List<Settlement> settlementsReceived;
  final List<Settlement> settlementsPaid;

  CashFlowSummaryData({
    required this.totalSpent,
    this.totalOutOfPocketPaid = 0.0,
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
        totalOutOfPocketPaid: 0,
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
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      throw Exception('Settling balances requires an active internet connection.');
    }

    // ── 1. Idempotency & Deduplication Guard ──
    // Guard against rapid duplicate clicks/invocations:
    // Check if an identical settlement (same group, payer, recipient, and matching amount)
    // was created recently (within last 120 seconds).
    try {
      final existingRes = await _tablesDB.listRows(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.settlementsCollection,
        queries: [
          Query.equal('groupId', groupId),
          Query.equal('fromUserId', fromUserId),
          Query.equal('toUserId', toUserId),
          Query.orderDesc('createdAt'),
          Query.limit(5),
        ],
      );

      final now = DateTime.now();
      for (final doc in existingRes.rows) {
        final docAmount = (doc.data['amount'] as num?)?.toDouble() ?? 0.0;
        final createdAtStr = doc.data['createdAt'] as String?;
        final docCreatedAt = createdAtStr != null ? DateTime.tryParse(createdAtStr) : null;

        if ((docAmount - amount).abs() < 0.05) {
          if (docCreatedAt != null && now.difference(docCreatedAt).inSeconds.abs() < 120) {
            // Duplicate prevented: already settled within the last 2 minutes.
            return;
          }
        }
      }
    } catch (_) {}

    // ── 2. Expense Settlement Status Guard ──
    // If all referenced expenses are already settled, do not create duplicate settlement
    if (expenseIds.isNotEmpty) {
      try {
        bool allAlreadySettled = true;
        for (final expId in expenseIds) {
          final expDoc = await _tablesDB.getRow(
            databaseId: AppConstants.databaseId,
            tableId: AppConstants.expensesCollection,
            rowId: expId,
          );
          final isSettled = expDoc.data['isSettled'] == true;
          if (!isSettled) {
            allAlreadySettled = false;
            break;
          }
        }
        if (allAlreadySettled) {
          // All referenced expenses are already marked as settled!
          return;
        }
      } catch (_) {}
    }

    final settlementId = ID.unique();
    final data = {
      'groupId': groupId,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'amount': amount,
      'settledExpenseIds': expenseIds,
      'createdAt': DateTime.now().toIso8601String(),
    };

    await _tablesDB.createRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.settlementsCollection,
      rowId: settlementId,
      data: data,
    );

    // Evaluate if the entire group active cycle is now fully settled (all net balances == 0)
    try {
      final expRes = await _tablesDB.listRows(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.expensesCollection,
        queries: [
          Query.equal('groupId', groupId),
          Query.equal('isSettled', false),
        ],
      );
      final activeExpenses = expRes.rows.map((d) => Expense.fromMap(d.dataWithId)).toList();

      if (activeExpenses.isNotEmpty) {
        final memberRows = await _tablesDB.listRows(
          databaseId: AppConstants.databaseId,
          tableId: AppConstants.groupMembersCollection,
          queries: [Query.equal('groupId', groupId)],
        );
        final memberUserIds = memberRows.rows
            .map((r) => r.data['userId'] as String)
            .toList();

        if (memberUserIds.isEmpty) return;

        final activeExpIds = activeExpenses.map((e) => e.id).toList();
        final splitsRes = await _tablesDB.listRows(
          databaseId: AppConstants.databaseId,
          tableId: AppConstants.expenseSplitsCollection,
          queries: [
            Query.equal('expenseId', activeExpIds),
          ],
        );
        final allSplits = splitsRes.rows.map((d) => ExpenseSplit.fromMap(d.dataWithId)).toList();

        final setRes = await _tablesDB.listRows(
          databaseId: AppConstants.databaseId,
          tableId: AppConstants.settlementsCollection,
          queries: [Query.equal('groupId', groupId)],
        );
        final allSettlements = setRes.rows.map((d) => Settlement.fromMap(d.dataWithId)).toList();

        final calcResult = BalanceCalculator.calculateExpenseSplitBalances(
          expenses: activeExpenses,
          allSplits: allSplits,
          settlements: allSettlements,
          memberUserIds: memberUserIds,
        );

        if (calcResult.transactions.isEmpty &&
            calcResult.netBalances.isNotEmpty &&
            calcResult.netBalances.values.every((b) => b.abs() < 0.05)) {
          for (final exp in activeExpenses) {
            await _tablesDB.updateRow(
              databaseId: AppConstants.databaseId,
              tableId: AppConstants.expensesCollection,
              rowId: exp.id,
              data: {
                'isSettled': true,
                'settledAt': DateTime.now().toIso8601String(),
              },
            );
          }
        }
      }
    } catch (_) {}
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
  double totalOutOfPocketPaid = 0.0;

  final List<CashFlowActivityItem> activities = [];

  for (final e in expenses) {
    final isPersonal = e.groupId == null || e.groupId!.isEmpty;
    final isMine = e.userId == myUserId;
    final payerName = isMine ? 'You' : (profileNames[e.userId] ?? 'Member');

    if (isPersonal && isMine) {
      personalSpent += e.amount;
      totalOutOfPocketPaid += e.amount;
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
          totalBillAmount: e.amount,
          myShareAmount: e.amount,
          isPaidByMe: true,
        ),
      );
    } else if (!isPersonal) {
      final myShare = splitMap[e.id] ?? (isMine ? e.amount : 0.0);
      groupShareSpent += myShare;

      if (isMine) {
        // Current user paid the full bill at the counter!
        totalOutOfPocketPaid += e.amount;
        final friendsOwe = e.amount - myShare;
        activities.add(
          CashFlowActivityItem(
            id: e.id,
            type: CashFlowType.expense,
            title: e.description,
            subtitle: friendsOwe > 0
                ? 'Group: ${groupMap[e.groupId] ?? 'Group'} • Paid full bill (Your share: ₹${myShare.toStringAsFixed(0)})'
                : 'Group: ${groupMap[e.groupId] ?? 'Group'} • Paid full bill',
            groupName: groupMap[e.groupId] ?? 'Group',
            amount: e.amount,
            date: e.expenseDate,
            category: e.category,
            payerName: 'You',
            originalObject: e,
            totalBillAmount: e.amount,
            myShareAmount: myShare,
            isPaidByMe: true,
          ),
        );
      } else if (myShare > 0) {
        // Someone else paid at the counter, current user is a participant
        activities.add(
          CashFlowActivityItem(
            id: e.id,
            type: CashFlowType.expense,
            title: e.description,
            subtitle: 'Group: ${groupMap[e.groupId] ?? 'Group'} • Paid by $payerName (Bill: ₹${e.amount.toStringAsFixed(0)})',
            groupName: groupMap[e.groupId] ?? 'Group',
            amount: myShare,
            date: e.expenseDate,
            category: e.category,
            payerName: payerName,
            originalObject: e,
            totalBillAmount: e.amount,
            myShareAmount: myShare,
            isPaidByMe: false,
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
        subtitle: 'Settlement • ${groupMap[s.groupId] ?? 'Group'}',
        groupName: groupMap[s.groupId] ?? 'Group',
        amount: s.amount,
        date: s.createdAt,
        category: 'settled',
        payerName: fromName,
        originalObject: s,
        totalBillAmount: s.amount,
        myShareAmount: s.amount,
        isPaidByMe: false,
      ),
    );
  }

  // Add Settlements Paid
  double totalPaidOut = 0.0;
  for (final s in settlementsPaid) {
    totalPaidOut += s.amount;
    totalOutOfPocketPaid += s.amount;
    final toName = profileNames[s.toUserId] ?? 'Group Member';
    activities.add(
      CashFlowActivityItem(
        id: s.id,
        type: CashFlowType.settlementPaid,
        title: 'Paid to $toName',
        subtitle: 'Settlement • ${groupMap[s.groupId] ?? 'Group'}',
        groupName: groupMap[s.groupId] ?? 'Group',
        amount: s.amount,
        date: s.createdAt,
        category: 'settled',
        payerName: 'You',
        originalObject: s,
        totalBillAmount: s.amount,
        myShareAmount: s.amount,
        isPaidByMe: true,
      ),
    );
  }

  // Sort activities newest first
  activities.sort((a, b) => b.date.compareTo(a.date));

  final totalSpent = personalSpent + groupShareSpent;
  // Net cash flow = Total Received - Total Out-Of-Pocket Paid
  final netCashFlow = totalReceived - totalOutOfPocketPaid;

  return CashFlowSummaryData(
    totalSpent: totalSpent,
    totalOutOfPocketPaid: totalOutOfPocketPaid,
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
