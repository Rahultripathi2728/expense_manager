import '../../../app/constants/app_constants.dart';
import '../../expenses/domain/expense_model.dart';
import '../../expenses/domain/expense_split_model.dart';
import '../../expenses/domain/expense_item_model.dart';

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

  /// 7.2 — Group net balance per member.
  /// Returns a map of userId → net balance.
  /// net > 0 means the group owes the user.
  /// net < 0 means the user owes the group.
  static Map<String, double> calculateNetBalances({
    required List<Expense> expenses,
    required List<ExpenseSplit> allSplits,
  }) {
    final Map<String, double> paidTotal = {};
    final Map<String, double> owedTotal = {};

    for (final expense in expenses) {
      if (expense.isSettled) continue;

      // Paid total: who paid
      paidTotal[expense.userId] =
          (paidTotal[expense.userId] ?? 0) + expense.amount;

      // Owed total: sum of amountOwed from splits
      final expenseSplits = allSplits
          .where((s) => s.expenseId == expense.id)
          .toList();

      for (final split in expenseSplits) {
        if (split.isIncluded) {
          owedTotal[split.userId] =
              (owedTotal[split.userId] ?? 0) + split.amountOwed;
        }
      }
    }

    // Collect all user IDs
    final allUsers = {...paidTotal.keys, ...owedTotal.keys};

    // net = paid - owed
    final Map<String, double> net = {};
    for (final userId in allUsers) {
      net[userId] = (paidTotal[userId] ?? 0) - (owedTotal[userId] ?? 0);
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
