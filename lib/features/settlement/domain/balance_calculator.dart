import '../../../app/constants/app_constants.dart';
import '../../expenses/domain/expense_model.dart';
import '../../expenses/domain/expense_split_model.dart';
import '../../expenses/domain/expense_item_model.dart';

import '../domain/settlement_model.dart';

/// Transaction representing a simplified payment between two users.
class SimplifiedTransaction {
  final String fromUserId;
  final String toUserId;
  final double amount;

  const SimplifiedTransaction({
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
  });
}

/// Result of per-expense split balance calculation.
class ExpenseSplitBalanceResult {
  final Map<String, double> netBalances;
  final Map<String, double> paidAmounts;
  final Map<String, double> shareAmounts;
  final List<Expense> unsettledExpenses;
  final List<SimplifiedTransaction> transactions;

  const ExpenseSplitBalanceResult({
    required this.netBalances,
    required this.paidAmounts,
    required this.shareAmounts,
    required this.unsettledExpenses,
    required this.transactions,
  });
}

/// Core balance calculation engine.
/// Implements Section 7 of the spec exactly.
class BalanceCalculator {
  BalanceCalculator._();

  /// 7.1 — Member's owed amount per expense.
  /// Returns the amount owed by [userId] for [expense].
  static double memberOwedAmount({
    required Expense expense,
    required String userId,
    required List<ExpenseSplit> splits,
    required int memberCount,
  }) {
    // Settled expenses contribute 0
    if (expense.isSettled) return 0;

    // Check if splits exist for this expense+user
    final userSplit = splits
        .where((s) => s.expenseId == expense.id && s.userId == userId)
        .toList();

    if (userSplit.isNotEmpty) {
      return userSplit.first.amountOwed;
    }

    // Legacy fallback: equal division
    if (memberCount > 0) {
      return expense.amount / memberCount;
    }

    return 0;
  }

  /// Accurate per-expense split balance calculation.
  /// Evaluates each split: Remaining = AmountOwed - TotalSettledForThisExpense.
  /// If any debtor still has Remaining > 0, the expense is marked as unsettled.
  /// Solves multi-person partial settlements cleanly and permanently.
  static ExpenseSplitBalanceResult calculateExpenseSplitBalances({
    required List<Expense> expenses,
    required List<ExpenseSplit> allSplits,
    required List<Settlement> settlements,
    required List<String> memberUserIds,
  }) {
    final Map<String, double> netBalances = {for (var id in memberUserIds) id: 0.0};
    final Map<String, double> paidMap = {for (var id in memberUserIds) id: 0.0};
    final Map<String, double> shareMap = {for (var id in memberUserIds) id: 0.0};
    final List<Expense> unsettledExpenses = [];

    // Filter out expenses that are already archived/settled
    final activeExpenses = expenses.where((e) => !e.isSettled).toList();

    for (final exp in activeExpenses) {
      final payerId = exp.userId;
      final expSplits = allSplits.where((s) => s.expenseId == exp.id && s.isIncluded).toList();

      bool expHasOutstanding = false;

      if (expSplits.isNotEmpty) {
        for (final split in expSplits) {
          final debtorId = split.userId;
          if (debtorId == payerId) {
            // Payer's own share is paid by definition
            continue;
          }

          final owed = split.amountOwed;

          // Find settlements from this debtor to this payer for this specific expense
          final settledAmount = settlements
              .where((s) =>
                  s.fromUserId == debtorId &&
                  s.toUserId == payerId &&
                  s.settledExpenseIds.contains(exp.id))
              .fold<double>(0.0, (sum, s) => sum + s.amount);

          final remaining = owed - settledAmount;
          if (remaining > AppConstants.splitEpsilon) {
            expHasOutstanding = true;
            netBalances[debtorId] = (netBalances[debtorId] ?? 0.0) - remaining;
            netBalances[payerId] = (netBalances[payerId] ?? 0.0) + remaining;
            shareMap[debtorId] = (shareMap[debtorId] ?? 0.0) + remaining;
            paidMap[payerId] = (paidMap[payerId] ?? 0.0) + remaining;
          }
        }
      } else if (memberUserIds.isNotEmpty) {
        // Fallback for legacy expenses with no stored splits
        final splitAmt = exp.amount / memberUserIds.length;
        for (final mId in memberUserIds) {
          if (mId == payerId) continue;
          final settledAmount = settlements
              .where((s) =>
                  s.fromUserId == mId &&
                  s.toUserId == payerId &&
                  s.settledExpenseIds.contains(exp.id))
              .fold<double>(0.0, (sum, s) => sum + s.amount);
          final remaining = splitAmt - settledAmount;
          if (remaining > AppConstants.splitEpsilon) {
            expHasOutstanding = true;
            netBalances[mId] = (netBalances[mId] ?? 0.0) - remaining;
            netBalances[payerId] = (netBalances[payerId] ?? 0.0) + remaining;
            shareMap[mId] = (shareMap[mId] ?? 0.0) + remaining;
            paidMap[payerId] = (paidMap[payerId] ?? 0.0) + remaining;
          }
        }
      }

      if (expHasOutstanding) {
        unsettledExpenses.add(exp);
      }
    }

    // Process any direct cash settlements that were not tied to specific expense IDs
    for (final s in settlements) {
      if (s.settledExpenseIds.isEmpty) {
        netBalances[s.fromUserId] = (netBalances[s.fromUserId] ?? 0.0) + s.amount;
        netBalances[s.toUserId] = (netBalances[s.toUserId] ?? 0.0) - s.amount;
      }
    }

    // Clean up floating point epsilon
    netBalances.forEach((k, v) {
      if (v.abs() < AppConstants.splitEpsilon) {
        netBalances[k] = 0.0;
      }
    });

    final transactions = simplifyTransactions(netBalances);

    return ExpenseSplitBalanceResult(
      netBalances: netBalances,
      paidAmounts: paidMap,
      shareAmounts: shareMap,
      unsettledExpenses: unsettledExpenses,
      transactions: transactions,
    );
  }

  /// 7.2 — Group net balance per member using Splitwise Cumulative Ledger.
  /// Net = (PaidExpenses + SettlementsPaidOut) - (OwedSplits + SettlementsReceived)
  /// net > 0 means the group owes the user (Gets back).
  /// net < 0 means the user owes the group (Owes).
  static Map<String, double> calculateNetBalances({
    required List<Expense> expenses,
    required List<ExpenseSplit> allSplits,
    List<Settlement> settlements = const [],
  }) {
    final Map<String, double> paidTotal = {};
    final Map<String, double> owedTotal = {};
    final Map<String, double> settlementsPaidOut = {};
    final Map<String, double> settlementsReceived = {};

    for (final expense in expenses) {
      if (expense.isSettled) continue;

      // Paid total: who paid
      paidTotal[expense.userId] =
          (paidTotal[expense.userId] ?? 0.0) + expense.amount;

      // Owed total: sum of amountOwed from splits
      final expenseSplits = allSplits
          .where((s) => s.expenseId == expense.id)
          .toList();

      final activeSplits = expenseSplits.where((s) => s.isIncluded).toList();
      double totalSplitOwed = 0.0;
      for (final split in activeSplits) {
        totalSplitOwed += split.amountOwed;
      }

      if (activeSplits.isEmpty) {
        // Fallback: if no active splits, assume payer owes it fully to balance the ledger
        owedTotal[expense.userId] =
            (owedTotal[expense.userId] ?? 0.0) + expense.amount;
      } else {
        // Normalize to ensure total owed == expense.amount
        for (final split in activeSplits) {
          double normalizedOwed = split.amountOwed;
          if (totalSplitOwed > 0.01 && (totalSplitOwed - expense.amount).abs() > 0.01) {
            normalizedOwed = (split.amountOwed / totalSplitOwed) * expense.amount;
          }
          owedTotal[split.userId] =
              (owedTotal[split.userId] ?? 0.0) + normalizedOwed;
        }
      }
    }

    // Apply Settlements
    for (final s in settlements) {
      settlementsPaidOut[s.fromUserId] =
          (settlementsPaidOut[s.fromUserId] ?? 0.0) + s.amount;
      settlementsReceived[s.toUserId] =
          (settlementsReceived[s.toUserId] ?? 0.0) + s.amount;
    }

    // Collect all user IDs
    final allUsers = {
      ...paidTotal.keys,
      ...owedTotal.keys,
      ...settlementsPaidOut.keys,
      ...settlementsReceived.keys,
    };

    // net = (paid + settlementsPaidOut) - (owed + settlementsReceived)
    final Map<String, double> net = {};
    for (final userId in allUsers) {
      final totalCredit = (paidTotal[userId] ?? 0.0) + (settlementsPaidOut[userId] ?? 0.0);
      final totalDebit = (owedTotal[userId] ?? 0.0) + (settlementsReceived[userId] ?? 0.0);
      final balance = totalCredit - totalDebit;
      net[userId] = balance.abs() < AppConstants.splitEpsilon ? 0.0 : balance;
    }

    return net;
  }

  /// 7.3 — Simplified transactions using greedy algorithm.
  /// Minimizes the number of transactions.
  static List<SimplifiedTransaction> simplifyTransactions(
    Map<String, double> netBalances,
  ) {
    final List<SimplifiedTransaction> transactions = [];
    const epsilon = AppConstants.splitEpsilon;

    // Separate creditors (net > 0) and debtors (net < 0)
    final creditors = <MapEntry<String, double>>[];
    final debtors = <MapEntry<String, double>>[];

    for (final entry in netBalances.entries) {
      if (entry.value > epsilon) {
        creditors.add(entry);
      } else if (entry.value < -epsilon) {
        debtors.add(entry);
      }
    }

    // Sort: largest creditor and largest debtor first
    creditors.sort((a, b) => b.value.compareTo(a.value));
    debtors.sort((a, b) => a.value.compareTo(b.value)); // most negative first

    // Make mutable copies
    final creditMap = {for (final e in creditors) e.key: e.value};
    final debtMap = {for (final e in debtors) e.key: e.value.abs()};

    while (creditMap.isNotEmpty && debtMap.isNotEmpty) {
      // Find largest creditor and largest debtor
      final creditor = creditMap.entries.reduce(
        (a, b) => a.value >= b.value ? a : b,
      );
      final debtor = debtMap.entries.reduce(
        (a, b) => a.value >= b.value ? a : b,
      );

      final amount = creditor.value < debtor.value
          ? creditor.value
          : debtor.value;

      if (amount > epsilon) {
        transactions.add(
          SimplifiedTransaction(
            fromUserId: debtor.key,
            toUserId: creditor.key,
            amount: double.parse(amount.toStringAsFixed(2)),
          ),
        );
      }

      creditMap[creditor.key] = creditor.value - amount;
      debtMap[debtor.key] = debtor.value - amount;

      if (creditMap[creditor.key]! < epsilon) creditMap.remove(creditor.key);
      if (debtMap[debtor.key]! < epsilon) debtMap.remove(debtor.key);
    }

    return transactions;
  }

  /// 7.4 — Itemwise split calculation.
  /// Returns a map of userId → total amount owed.
  static Map<String, double> calculateItemwiseSplit(List<ExpenseItem> items) {
    final Map<String, double> amountOwed = {};

    for (final item in items) {
      if (item.participants.isEmpty) continue;
      final perParticipant = item.itemAmount / item.participants.length;

      for (final userId in item.participants) {
        amountOwed[userId] = (amountOwed[userId] ?? 0) + perParticipant;
      }
    }

    return amountOwed;
  }

  /// 7.5 — Unequal split validation.
  /// Returns true if the sum of amounts is within epsilon of totalAmount.
  static bool validateUnequalSplit({
    required double totalAmount,
    required Map<String, double> amounts,
  }) {
    final sum = amounts.values.fold<double>(0, (a, b) => a + b);
    return (sum - totalAmount).abs() < AppConstants.splitEpsilon;
  }

  /// 7.6 — Monthly budget percentage.
  static double budgetPercentage({
    required double spentThisMonth,
    required double monthlyBudget,
  }) {
    if (monthlyBudget <= 0) return 0;
    return (spentThisMonth / monthlyBudget) * 100;
  }

  /// Budget color zone based on percentage.
  /// Green < 60%, Amber 60-90%, Red ≥ 90%
  static String budgetZone(double percentage) {
    if (percentage >= 90) return 'danger';
    if (percentage >= 60) return 'warning';
    return 'safe';
  }
}
