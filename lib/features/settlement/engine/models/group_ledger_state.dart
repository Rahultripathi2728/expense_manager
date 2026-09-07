import '../../../../app/constants/app_constants.dart';
import '../../../expenses/domain/expense_model.dart';
import '../../../expenses/domain/expense_split_model.dart';
import '../../../profile/domain/profile_model.dart';
import '../../domain/settlement_model.dart';
import 'simplified_debt.dart';

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

  /// Golden Rule: An expense is ONLY locked from editing or deletion if:
  /// 1. It is explicitly marked settled in DB (`expense.isSettled == true`).
  /// 2. OR an actual cash settlement has been recorded in DB referencing this expense ID.
  /// Adding new bills or having a positive/negative net balance NEVER locks an expense!
  bool isExpenseLocked(Expense expense) {
    if (expense.isSettled) return true;
    return settlements.any((s) => s.settledExpenseIds.contains(expense.id));
  }

  /// Whether an expense is fully settled.
  bool isExpenseFullySettled(Expense expense) {
    if (expense.isSettled) return true;
    return isExpenseLocked(expense);
  }

  /// Whether an expense has any recorded settlements against it.
  bool isExpensePartiallyOrFullySettled(Expense expense) {
    return isExpenseLocked(expense);
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
