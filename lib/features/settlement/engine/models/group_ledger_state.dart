import '../../../../app/constants/app_constants.dart';
import '../../../expenses/domain/expense_model.dart';
import '../../../expenses/domain/expense_split_model.dart';
import '../../../profile/domain/profile_model.dart';
import '../../domain/settlement_model.dart';
import 'simplified_debt.dart';

enum ExpenseSettlementStatus {
  unsettled,
  partiallySettled,
  fullySettled,
}

/// Complete, immutable state of a group's cumulative financial ledger.
class GroupLedgerState {
  final int membersCount;
  final Map<String, Profile> profiles;
  final Map<String, double> netBalances;
  final Map<String, double> billsPaidByMember;
  final Map<String, double> billShareByMember;
  final Map<String, double> cashSettlementsPaid;
  final Map<String, double> cashSettlementsReceived;
  final List<SimplifiedDebt> transactions;
  final List<Expense> unsettledExpenses;
  final List<Expense> allExpenses;
  final List<Settlement> settlements;
  final Map<String, List<ExpenseSplit>> splitsByExpense;
  final Settlement? lastSettlement;

  const GroupLedgerState({
    required this.membersCount,
    required this.profiles,
    required this.netBalances,
    required this.billsPaidByMember,
    required this.billShareByMember,
    required this.cashSettlementsPaid,
    required this.cashSettlementsReceived,
    required this.transactions,
    required this.unsettledExpenses,
    required this.allExpenses,
    required this.settlements,
    required this.splitsByExpense,
    this.lastSettlement,
  });

  /// Factory for an empty ledger (e.g. while loading or with no members).
  factory GroupLedgerState.empty() => const GroupLedgerState(
        membersCount: 0,
        profiles: {},
        netBalances: {},
        billsPaidByMember: {},
        billShareByMember: {},
        cashSettlementsPaid: {},
        cashSettlementsReceived: {},
        transactions: [],
        unsettledExpenses: [],
        allExpenses: [],
        settlements: [],
        splitsByExpense: {},
        lastSettlement: null,
      );

  // ── Helper Getters & Domain Rules ──

  int get unsettledExpensesCount => unsettledExpenses.length;

  double get totalUnsettledAmount => unsettledExpenses.fold<double>(
        0.0,
        (sum, e) => sum + e.amount,
      );

  /// Returns the settlement status for an expense:
  /// - fullySettled: marked settled in DB or ALL included debtors have recorded settlements.
  /// - partiallySettled: at least 1 debtor has recorded a settlement, but other debtors remain pending.
  /// - unsettled: no debtors have settled.
  ExpenseSettlementStatus getExpenseSettlementStatus(Expense expense) {
    if (expense.isSettled) return ExpenseSettlementStatus.fullySettled;

    final splits = splitsByExpense[expense.id] ?? [];
    final debtorIds = splits
        .where((s) => s.userId != expense.userId && s.isIncluded)
        .map((s) => s.userId)
        .toSet();

    final settlementsForExp = settlements
        .where((s) => s.settledExpenseIds.contains(expense.id))
        .toList();

    if (settlementsForExp.isEmpty) {
      return ExpenseSettlementStatus.unsettled;
    }

    if (debtorIds.isEmpty) {
      return ExpenseSettlementStatus.fullySettled;
    }

    final settledDebtorIds = settlementsForExp.map((s) => s.fromUserId).toSet();
    final allSettled = debtorIds.every(settledDebtorIds.contains);

    if (allSettled) {
      return ExpenseSettlementStatus.fullySettled;
    } else {
      return ExpenseSettlementStatus.partiallySettled;
    }
  }

  /// True ONLY when the entire bill is completely settled by all participants.
  bool isExpenseFullySettled(Expense expense) {
    return getExpenseSettlementStatus(expense) == ExpenseSettlementStatus.fullySettled;
  }

  /// True when some participants have paid, but others are still pending.
  bool isExpensePartiallySettled(Expense expense) {
    return getExpenseSettlementStatus(expense) == ExpenseSettlementStatus.partiallySettled;
  }

  /// An expense is locked if it is either partially or fully settled.
  /// (Cannot edit or delete if any member has already paid their share!).
  bool isExpenseLocked(Expense expense) {
    final status = getExpenseSettlementStatus(expense);
    return status == ExpenseSettlementStatus.partiallySettled ||
        status == ExpenseSettlementStatus.fullySettled;
  }

  /// Whether an expense has any recorded settlements against it.
  bool isExpensePartiallyOrFullySettled(Expense expense) {
    return isExpenseLocked(expense);
  }

  /// Count of debtors who have settled their share for this expense.
  int getSettledDebtorsCount(Expense expense) {
    final splits = splitsByExpense[expense.id] ?? [];
    final debtorIds = splits
        .where((s) => s.userId != expense.userId && s.isIncluded)
        .map((s) => s.userId)
        .toSet();
    final settlementsForExp = settlements
        .where((s) => s.settledExpenseIds.contains(expense.id))
        .toList();
    final settledDebtors = settlementsForExp
        .map((s) => s.fromUserId)
        .where(debtorIds.contains)
        .toSet();
    return settledDebtors.length;
  }

  /// Total count of debtors who owe for this expense.
  int getTotalDebtorsCount(Expense expense) {
    final splits = splitsByExpense[expense.id] ?? [];
    return splits.where((s) => s.userId != expense.userId && s.isIncluded).length;
  }

  /// Returns the net balance for a given user.
  /// > 0: user gets back money.
  /// < 0: user owes money.
  /// == 0: user is settled up.
  double getMemberNet(String userId) {
    final net = netBalances[userId] ?? 0.0;
    return net.abs() < AppConstants.splitEpsilon ? 0.0 : net;
  }

  /// Whether a member is completely settled up in the group.
  bool isMemberSettled(String userId) {
    return (netBalances[userId] ?? 0.0).abs() < AppConstants.splitEpsilon;
  }
}
