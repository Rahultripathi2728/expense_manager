import '../../../app/constants/app_constants.dart';
import '../../expenses/domain/expense_model.dart';
import '../../expenses/domain/expense_split_model.dart';
import '../../profile/domain/profile_model.dart';
import '../domain/settlement_model.dart';
import 'models/group_ledger_state.dart';
import 'models/simplified_debt.dart';

/// Pure, deterministic calculation engine for group financial balances and settlements.
/// Decoupled from all UI logic to guarantee bulletproof accounting integrity.
class SettlementEngine {
  SettlementEngine._();

  /// Computes the complete cumulative ledger state for a group.
  ///
  /// Mathematical Invariant:
  /// Total Credits == Total Debits, and sum(netBalances) == 0.0 at all times.
  static GroupLedgerState computeLedger({
    required List<String> memberUserIds,
    required List<Expense> expenses,
    required List<ExpenseSplit> allSplits,
    required List<Settlement> settlements,
    Map<String, Profile> profiles = const {},
  }) {
    if (memberUserIds.isEmpty) {
      return GroupLedgerState.empty();
    }

    // 1. Identify active (unsettled) expenses
    // An expense is only considered settled if marked isSettled == true in DB
    final unsettledExpenses = expenses.where((e) => !e.isSettled).toList();

    // 2. Initialize tracking maps for all members
    final Map<String, double> billsPaid = {for (var id in memberUserIds) id: 0.0};
    final Map<String, double> billShare = {for (var id in memberUserIds) id: 0.0};
    final Map<String, double> settlementsPaidOut = {for (var id in memberUserIds) id: 0.0};
    final Map<String, double> settlementsReceived = {for (var id in memberUserIds) id: 0.0};
    final Map<String, double> netBalances = {for (var id in memberUserIds) id: 0.0};

    // 3. Compute bills paid and bill share for active expenses
    for (final exp in unsettledExpenses) {
      billsPaid[exp.userId] = (billsPaid[exp.userId] ?? 0.0) + exp.amount;

      final expSplits = allSplits.where((s) => s.expenseId == exp.id && s.isIncluded).toList();
      double totalSplitOwed = 0.0;
      for (final split in expSplits) {
        totalSplitOwed += split.amountOwed;
      }

      if (expSplits.isEmpty) {
        // Fallback: if no active splits, payer takes full share
        billShare[exp.userId] = (billShare[exp.userId] ?? 0.0) + exp.amount;
      } else {
        // Normalize splits to guarantee sum(shares) == exp.amount
        for (final split in expSplits) {
          double normalizedOwed = split.amountOwed;
          if (totalSplitOwed > 0.01 && (totalSplitOwed - exp.amount).abs() > 0.01) {
            normalizedOwed = (split.amountOwed / totalSplitOwed) * exp.amount;
          }
          billShare[split.userId] = (billShare[split.userId] ?? 0.0) + normalizedOwed;
        }
      }
    }

    // 4. Apply settlements
    // Settlements that belong to the current active cycle (link to active expenses)
    final unsettledExpIds = unsettledExpenses.map((e) => e.id).toSet();
    final activeSettlements = settlements.where((s) {
      if (s.settledExpenseIds.isEmpty) return true;
      return s.settledExpenseIds.any((id) => unsettledExpIds.contains(id));
    }).toList();

    for (final s in activeSettlements) {
      settlementsPaidOut[s.fromUserId] = (settlementsPaidOut[s.fromUserId] ?? 0.0) + s.amount;
      settlementsReceived[s.toUserId] = (settlementsReceived[s.toUserId] ?? 0.0) + s.amount;
    }

    // 5. Cumulative Net Balance:
    // Net = (Bills Paid + Settlements Paid Out) - (Bill Share + Settlements Received)
    // Positive (+) => Gets back money from group
    // Negative (-) => Owes money to group
    // Zero (0)     => Settled up
    for (final id in memberUserIds) {
      final totalCredit = (billsPaid[id] ?? 0.0) + (settlementsPaidOut[id] ?? 0.0);
      final totalDebit = (billShare[id] ?? 0.0) + (settlementsReceived[id] ?? 0.0);
      final balance = totalCredit - totalDebit;
      netBalances[id] = balance.abs() < AppConstants.splitEpsilon ? 0.0 : balance;
    }

    // 6. Greedy debt simplification
    final transactions = simplifyDebts(netBalances);

    // Group splits by expense ID for quick access
    final Map<String, List<ExpenseSplit>> splitsByExpense = {};
    for (final exp in expenses) {
      splitsByExpense[exp.id] = allSplits.where((s) => s.expenseId == exp.id).toList();
    }

    final Settlement? lastSettlement = settlements.isNotEmpty ? settlements.first : null;

    return GroupLedgerState(
      membersCount: memberUserIds.length,
      profiles: profiles,
      netBalances: netBalances,
      billsPaidByMember: billsPaid,
      billShareByMember: billShare,
      cashSettlementsPaid: settlementsPaidOut,
      cashSettlementsReceived: settlementsReceived,
      transactions: transactions,
      unsettledExpenses: unsettledExpenses,
      allExpenses: expenses,
      settlements: settlements,
      splitsByExpense: splitsByExpense,
      lastSettlement: lastSettlement,
    );
  }

  /// Greedy min-cash-flow algorithm to minimize the number of payment transfers.
  static List<SimplifiedDebt> simplifyDebts(Map<String, double> netBalances) {
    final List<SimplifiedDebt> transactions = [];
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

    final creditMap = {for (final e in creditors) e.key: e.value};
    final debtMap = {for (final e in debtors) e.key: e.value.abs()};

    while (creditMap.isNotEmpty && debtMap.isNotEmpty) {
      final creditor = creditMap.entries.reduce((a, b) => a.value >= b.value ? a : b);
      final debtor = debtMap.entries.reduce((a, b) => a.value >= b.value ? a : b);

      final amount = creditor.value < debtor.value ? creditor.value : debtor.value;

      if (amount > epsilon) {
        transactions.add(
          SimplifiedDebt(
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
}
