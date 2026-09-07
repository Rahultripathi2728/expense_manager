import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:expense_manager/app/theme/theme_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../shared/widgets/animation_helpers.dart';
import '../../../core/utils/date_helpers.dart';
import '../../../core/utils/haptic_helper.dart';
import '../data/expense_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../domain/expense_model.dart';
import '../../profile/domain/profile_model.dart';
import '../../auth/data/auth_repository.dart';
import '../../settlement/data/settlement_repository.dart';
import '../../../shared/widgets/skeleton_loading_card.dart';
import '../../../shared/widgets/custom_error_widget.dart';
import '../../../core/services/cache_service.dart';
import 'export/statement_export_screen.dart';
import 'utils/category_icon_helper.dart';

// Providers to track active states
final expensesTabProvider = StateProvider<int>((ref) => 0);
final analyticsMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});
final expenseFilterDateRangeProvider = StateProvider<DateTimeRange?>((ref) => null);
final cashFlowFilterTabProvider = StateProvider<String>((ref) => 'all'); // 'all', 'expense', 'received', 'paid'

class MyExpensesPage extends ConsumerWidget {
  const MyExpensesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(themeProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: const SafeArea(child: _MyExpensesView()),
    );
  }
}

class _MyExpensesView extends ConsumerWidget {
  const _MyExpensesView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(themeProvider);
    return const _MyExpensesTab();
  }
}

class _MyExpensesTab extends ConsumerWidget {
  const _MyExpensesTab();

  void _showEditBudgetDialog(
    BuildContext context,
    WidgetRef ref,
    Profile profile,
    DateTime month,
  ) {
    final ym = DateFormat('yyyy-MM').format(month);
    final currentBudget = ref.read(cacheServiceProvider).getMonthlyBudgetForMonth(
          ym,
          profile.monthlyBudget > 0 ? profile.monthlyBudget : 10000.0,
        );
    final controller = TextEditingController(
      text: currentBudget.toStringAsFixed(0),
    );
    bool loading = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: AppColors.surface,
          title: Text(
            'Edit Budget (${DateHelpers.formatMonthYear(month)})',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Budget Amount (₹)',
              hintText: 'Enter budget for ${DateHelpers.formatMonthYear(month)}',
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.textPrimary,
                      foregroundColor: AppColors.surface,
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: loading
                        ? null
                        : () async {
                            setState(() => loading = true);
                            try {
                              final val =
                                  double.tryParse(controller.text) ?? 0.0;
                              await ref
                                  .read(cacheServiceProvider)
                                  .saveMonthlyBudget(ym, val);
                              final updated = profile.copyWith(
                                monthlyBudget: val,
                              );
                              await ref
                                  .read(profileRepositoryProvider)
                                  .updateProfile(updated);
                              ref.invalidate(currentProfileProvider);
                              if (context.mounted) Navigator.pop(context);
                            } finally {
                              if (context.mounted) {
                                setState(() => loading = false);
                              }
                            }
                          },
                    child: loading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.surface,
                            ),
                          )
                        : const Text(
                            'Save',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _pickCustomDateRange(BuildContext context, WidgetRef ref, DateTime currentMonth) async {
    final currentRange = ref.read(expenseFilterDateRangeProvider);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: currentRange ??
          DateTimeRange(
            start: DateTime(currentMonth.year, currentMonth.month, 1),
            end: DateTime(currentMonth.year, currentMonth.month + 1, 0),
          ),
    );
    if (picked != null) {
      ref.read(expenseFilterDateRangeProvider.notifier).state = picked;
    }
  }

  void _showExportStatementModal({
    required BuildContext context,
    required WidgetRef ref,
    required DateTime month,
    required DateTimeRange? filterDateRange,
    required List<Expense> expenses,
    required CashFlowSummaryData? cashFlow,
    required String? userName,
  }) {
    HapticHelper.mediumTap();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StatementExportScreen(
          initialMonth: month,
          initialDateRange: filterDateRange,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(themeProvider);
    final month = ref.watch(analyticsMonthProvider);
    final expensesAsync = ref.watch(monthlyExpensesProvider(month));
    final splitsAsync = ref.watch(userSplitsProvider);
    final profileAsync = ref.watch(currentProfileProvider);
    final itemsAsync = ref.watch(monthlyExpenseItemsProvider(month));
    final cashFlowAsync = ref.watch(userCashFlowProvider(month));
    final currentUser = ref.watch(authStateProvider).valueOrNull;
    final filterDateRange = ref.watch(expenseFilterDateRangeProvider);
    final activeCashFlowFilter = ref.watch(cashFlowFilterTabProvider);
    final hasActiveFilter = filterDateRange != null;

    final userSplits = splitsAsync.valueOrNull ?? [];
    final expenseItems = itemsAsync.valueOrNull ?? [];
    final myUserId = currentUser?.id;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date selection row
          Row(
            children: [
              // Previous month
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.borderLight),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.chevron_left_rounded,
                    color: AppColors.textPrimary,
                    size: 22,
                  ),
                  onPressed: () {
                    HapticHelper.lightTap();
                    ref.read(expenseFilterDateRangeProvider.notifier).state = null;
                    ref.read(analyticsMonthProvider.notifier).state =
                        DateHelpers.previousMonth(month);
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Current month / Date Range display
              Expanded(
                child: GestureDetector(
                  onTap: () => _pickCustomDateRange(context, ref, month),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.borderLight),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            filterDateRange != null
                                ? '${DateHelpers.formatDayMonth(filterDateRange.start)} - ${DateHelpers.formatDayMonth(filterDateRange.end)}'
                                : DateHelpers.formatMonthYear(month),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (DateHelpers.isCurrentMonth(month) && filterDateRange == null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.borderLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Now',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Next month
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.borderLight),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textPrimary,
                    size: 22,
                  ),
                  onPressed: () {
                    HapticHelper.lightTap();
                    ref.read(expenseFilterDateRangeProvider.notifier).state = null;
                    ref.read(analyticsMonthProvider.notifier).state =
                        DateHelpers.nextMonth(month);
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Custom Date Filter Button
              Container(
                decoration: BoxDecoration(
                  color: hasActiveFilter ? AppColors.primary : AppColors.surface,
                  border: Border.all(
                    color: hasActiveFilter ? AppColors.primary : AppColors.borderLight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: Icon(
                    hasActiveFilter ? Icons.close_rounded : Icons.tune_rounded,
                    color: hasActiveFilter ? Colors.white : AppColors.textPrimary,
                    size: 20,
                  ),
                  onPressed: () {
                    HapticHelper.lightTap();
                    if (hasActiveFilter) {
                      ref.read(expenseFilterDateRangeProvider.notifier).state = null;
                    } else {
                      _pickCustomDateRange(context, ref, month);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          expensesAsync.when(
            skipLoadingOnReload: true,
            skipLoadingOnRefresh: true,
            loading: () => const Padding(
              padding: EdgeInsets.only(top: 20),
              child: SkeletonList(itemCount: 4),
            ),
            error: (err, _) => CustomErrorWidget(
              error: err,
              onRetry: () => ref.invalidate(monthlyExpensesProvider(month)),
            ),
            data: (rawExpenses) {
              var expenses = rawExpenses;
              if (filterDateRange != null) {
                expenses = rawExpenses.where((e) {
                  return e.expenseDate.isAfter(filterDateRange.start.subtract(const Duration(seconds: 1))) &&
                      e.expenseDate.isBefore(filterDateRange.end.add(const Duration(days: 1)));
                }).toList();
              }

              double personalTotal = expenses
                  .where((e) => e.isPersonal)
                  .fold<double>(0.0, (sum, e) => sum + e.amount);
              double groupShareTotal = 0.0;
              for (final e in expenses.where((e) => e.isGroup)) {
                final match = userSplits
                    .where((s) => s.expenseId == e.id && s.userId == myUserId)
                    .toList();
                double amountOwed = match.isNotEmpty ? match.first.amountOwed : 0.0;

                if (e.splitType == 'itemwise') {
                  final items = expenseItems.where((i) => i.expenseId == e.id).toList();
                  double purelyPersonal = 0.0;
                  for (final item in items) {
                    if (item.participants.length == 1 && item.participants.first == myUserId) {
                      purelyPersonal += item.itemAmount;
                    }
                  }
                  personalTotal += purelyPersonal;
                  groupShareTotal += (amountOwed - purelyPersonal);
                } else if (amountOwed == e.amount && e.amount > 0) {
                  personalTotal += amountOwed;
                } else {
                  groupShareTotal += amountOwed;
                }
              }

              final totalSpent = personalTotal + groupShareTotal;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Budget Progress Card with scale-in
                  ScaleIn(
                    duration: const Duration(milliseconds: 600),
                    child: profileAsync.when(
                      loading: () => const SizedBox(),
                      error: (_, __) => const SizedBox(),
                      data: (profile) {
                        final ym = DateFormat('yyyy-MM').format(month);
                        final budget = ref.watch(cacheServiceProvider).getMonthlyBudgetForMonth(
                              ym,
                              profile?.monthlyBudget ?? 10000.0,
                            );
                        final percentage = budget > 0
                            ? (totalSpent / budget) * 100
                            : 0.0;
                        final remaining = budget - totalSpent;

                        final isOverBudget = remaining < 0;
                        final progressColor = percentage >= 90
                            ? const Color(0xFFEF4444)
                            : percentage >= 60
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF10B981);

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.borderLight),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header: Title & Edit Action
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          Icons.account_balance_wallet_rounded,
                                          size: 16,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Monthly Budget',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (profile != null)
                                    GestureDetector(
                                      onTap: () => _showEditBudgetDialog(
                                        context,
                                        ref,
                                        profile,
                                        month,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceVariant,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: AppColors.borderLight),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.edit_outlined,
                                              size: 12,
                                              color: AppColors.textSecondary,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Edit',
                                              style: TextStyle(
                                                color: AppColors.textSecondary,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Amounts Row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(
                                        DateHelpers.formatCurrency(totalSpent),
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                          color: isOverBudget ? const Color(0xFFEF4444) : AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'spent',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    'Limit: ${DateHelpers.formatCurrency(budget)}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Sleek Progress Bar
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: budget > 0
                                      ? (totalSpent / budget).clamp(0.0, 1.0)
                                      : 0.0,
                                  minHeight: 6,
                                  backgroundColor: AppColors.borderLight,
                                  color: progressColor,
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Footer: Usage & Remaining
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${percentage.toStringAsFixed(0)}% used',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                                  Text(
                                    remaining >= 0
                                        ? '${DateHelpers.formatCurrency(remaining)} remaining'
                                        : '${DateHelpers.formatCurrency(-remaining)} over budget',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isOverBudget ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Personal and Group breakdown cards side-by-side with fade-slide
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 200),
                    child: Row(
                      children: [
                        // Personal Card (Left)
                        Expanded(
                          child: GestureDetector(
                            onTap: () => context.push('/personal-expenses', extra: month),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.borderLight),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.person_rounded,
                                          color: Color(0xFF10B981),
                                          size: 18,
                                        ),
                                      ),
                                      Icon(
                                        Icons.arrow_forward_ios_rounded,
                                        size: 13,
                                        color: AppColors.textTertiary,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Personal',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateHelpers.formatCurrency(personalTotal),
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF10B981),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Group Share Card (Right)
                        Expanded(
                          child: GestureDetector(
                            onTap: () => context.push('/group-share-selection', extra: month),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.borderLight),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(alpha: 0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.groups_rounded,
                                          color: AppColors.primary,
                                          size: 18,
                                        ),
                                      ),
                                      Icon(
                                        Icons.arrow_forward_ios_rounded,
                                        size: 13,
                                        color: AppColors.textTertiary,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'My Share (Group)',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateHelpers.formatCurrency(groupShareTotal),
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Consolidated Cash Flow & Settlement Overview (Directly on this Page)
                  cashFlowAsync.when(
                    loading: () => const SkeletonList(itemCount: 2),
                    error: (err, _) => Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('Cash Flow Data: $err', style: TextStyle(color: AppColors.error, fontSize: 12)),
                    ),
                    data: (cashFlow) {
                      final allActivities = cashFlow.activities;
                      final paidByMeActivities = allActivities.where((a) => a.isPaidByMe).toList();
                      final myShareActivities = allActivities.where((a) => a.type == CashFlowType.expense && !a.isPaidByMe).toList();
                      final receivedActivities = allActivities.where((a) => a.type == CashFlowType.settlementReceived).toList();
                      final paidActivities = allActivities.where((a) => a.type == CashFlowType.settlementPaid).toList();

                      final filteredActivities = allActivities.where((a) {
                        if (activeCashFlowFilter == 'paid_by_me') return a.isPaidByMe;
                        if (activeCashFlowFilter == 'my_share') return a.type == CashFlowType.expense && !a.isPaidByMe;
                        if (activeCashFlowFilter == 'received') return a.type == CashFlowType.settlementReceived;
                        if (activeCashFlowFilter == 'paid') return a.type == CashFlowType.settlementPaid;
                        return true;
                      }).toList();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Section Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.account_balance_wallet_rounded,
                                      size: 16,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Cash Flow & Settlements',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              InkWell(
                                onTap: () {
                                  HapticHelper.mediumTap();
                                  final currentExps = expensesAsync.valueOrNull ?? [];
                                  _showExportStatementModal(
                                    context: context,
                                    ref: ref,
                                    month: month,
                                    filterDateRange: filterDateRange,
                                    expenses: currentExps,
                                    cashFlow: cashFlowAsync.valueOrNull,
                                    userName: currentUser?.name ?? profileAsync.valueOrNull?.fullName,
                                  );
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: AppColors.primary.withValues(alpha: 0.25),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.picture_as_pdf_rounded,
                                        size: 14,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        'Export PDF',
                                        style: TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // 4 Interactive Metric Cards Grid
                          Row(
                            children: [
                              // Total Out-of-Pocket Paid
                              Expanded(
                                child: _buildMetricCard(
                                  title: 'TOTAL PAID (POCKET)',
                                  amount: cashFlow.totalOutOfPocketPaid,
                                  color: AppColors.primary,
                                  icon: Icons.payments_rounded,
                                  isSelected: activeCashFlowFilter == 'paid_by_me',
                                  onTap: () {
                                    HapticHelper.selectionClick();
                                    ref.read(cashFlowFilterTabProvider.notifier).state =
                                        activeCashFlowFilter == 'paid_by_me' ? 'all' : 'paid_by_me';
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Received (+)
                              Expanded(
                                child: _buildMetricCard(
                                  title: 'RECEIVED (+)',
                                  amount: cashFlow.totalReceived,
                                  color: const Color(0xFF10B981),
                                  icon: Icons.arrow_downward_rounded,
                                  isSelected: activeCashFlowFilter == 'received',
                                  onTap: () {
                                    HapticHelper.selectionClick();
                                    ref.read(cashFlowFilterTabProvider.notifier).state =
                                        activeCashFlowFilter == 'received' ? 'all' : 'received';
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              // Paid Out (-)
                              Expanded(
                                child: _buildMetricCard(
                                  title: 'PAID TO FRIENDS (-)',
                                  amount: cashFlow.totalPaidOut,
                                  color: const Color(0xFFEF4444),
                                  icon: Icons.arrow_upward_rounded,
                                  isSelected: activeCashFlowFilter == 'paid',
                                  onTap: () {
                                    HapticHelper.selectionClick();
                                    ref.read(cashFlowFilterTabProvider.notifier).state =
                                        activeCashFlowFilter == 'paid' ? 'all' : 'paid';
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Net Cash Flow
                              Expanded(
                                child: _buildMetricCard(
                                  title: 'NET CASH FLOW',
                                  amount: cashFlow.netCashFlow,
                                  color: cashFlow.netCashFlow >= 0
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFEF4444),
                                  icon: Icons.swap_vert_rounded,
                                  isSelected: activeCashFlowFilter == 'all',
                                  isNet: true,
                                  onTap: () {
                                    HapticHelper.selectionClick();
                                    ref.read(cashFlowFilterTabProvider.notifier).state = 'all';
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Activity Filter Chips
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              children: [
                                _buildFilterChip(ref, 'all', 'All Activity (${allActivities.length})', activeCashFlowFilter),
                                const SizedBox(width: 8),
                                _buildFilterChip(ref, 'paid_by_me', '💳 Paid by You (${paidByMeActivities.length})', activeCashFlowFilter),
                                const SizedBox(width: 8),
                                _buildFilterChip(ref, 'my_share', '👥 My Share (${myShareActivities.length})', activeCashFlowFilter),
                                const SizedBox(width: 8),
                                _buildFilterChip(ref, 'received', '🟢 Received (${receivedActivities.length})', activeCashFlowFilter),
                                const SizedBox(width: 8),
                                _buildFilterChip(ref, 'paid', '🔴 Paid Out (${paidActivities.length})', activeCashFlowFilter),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Activity List (Consolidated Feed)
                          if (filteredActivities.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.borderLight),
                              ),
                              child: Text(
                                'No activity in this filter for ${DateHelpers.formatMonthYear(month)}.',
                                style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: filteredActivities.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, idx) {
                                final item = filteredActivities[idx];
                                return _buildActivityRow(context, item);
                              },
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 100), // padding at bottom
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required double amount,
    required Color color,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    bool isNet = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : AppColors.borderLight,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? color.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.02),
              blurRadius: isSelected ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? color : AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, color: color, size: 14),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isNet
                  ? '${amount >= 0 ? '+' : ''}${DateHelpers.formatCurrency(amount)}'
                  : DateHelpers.formatCurrency(amount),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(WidgetRef ref, String key, String label, String activeKey) {
    final isSelected = key == activeKey;
    return GestureDetector(
      onTap: () {
        HapticHelper.selectionClick();
        ref.read(cashFlowFilterTabProvider.notifier).state = key;
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.borderLight,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildActivityRow(BuildContext context, CashFlowActivityItem item) {
    final isExpense = item.type == CashFlowType.expense;
    final isReceived = item.type == CashFlowType.settlementReceived;

    final String amountText;
    final Color amountColor;
    final String tagText;
    final Color tagBgColor;
    final Color tagTextColor;

    if (isExpense) {
      if (item.isPaidByMe) {
        if (item.groupName == 'Personal') {
          amountText = '-${DateHelpers.formatCurrency(item.amount)}';
          amountColor = AppColors.textPrimary;
          tagText = 'Personal';
          tagBgColor = const Color(0xFF10B981).withValues(alpha: 0.12);
          tagTextColor = const Color(0xFF10B981);
        } else {
          amountText = '-${DateHelpers.formatCurrency(item.totalBillAmount > 0 ? item.totalBillAmount : item.amount)}';
          amountColor = const Color(0xFFEF4444);
          tagText = 'You Paid Full';
          tagBgColor = AppColors.primary.withValues(alpha: 0.12);
          tagTextColor = AppColors.primary;
        }
      } else {
        amountText = DateHelpers.formatCurrency(item.myShareAmount > 0 ? item.myShareAmount : item.amount);
        amountColor = const Color(0xFFD97706); // Amber
        tagText = 'Your Share';
        tagBgColor = const Color(0xFFFEF3C7);
        tagTextColor = const Color(0xFFD97706);
      }
    } else if (isReceived) {
      amountText = '+${DateHelpers.formatCurrency(item.amount)}';
      amountColor = const Color(0xFF10B981);
      tagText = 'Received';
      tagBgColor = const Color(0xFFDCFCE7);
      tagTextColor = const Color(0xFF16A34A);
    } else {
      amountText = '-${DateHelpers.formatCurrency(item.amount)}';
      amountColor = const Color(0xFFEF4444);
      tagText = 'Paid Out';
      tagBgColor = const Color(0xFFFEE2E2);
      tagTextColor = const Color(0xFFDC2626);
    }

    return InkWell(
      onTap: () {
        HapticHelper.lightTap();
        if (item.originalObject is Expense) {
          context.push('/expense-detail', extra: item.originalObject as Expense);
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left Icon
            if (isExpense)
              CategoryIconHelper.buildBadge(item.category ?? 'Other', size: 42, iconSize: 20)
            else
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isReceived
                      ? const Color(0xFF10B981).withValues(alpha: 0.12)
                      : const Color(0xFFEF4444).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isReceived ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                  color: isReceived ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  size: 20,
                ),
              ),
            const SizedBox(width: 12),

            // Middle Column: Title & Metadata
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Subtitle info
                  if (isExpense) ...[
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.groupName ?? 'Personal',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          ' • ${DateHelpers.formatDayMonth(item.date)}',
                          style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                        ),
                      ],
                    ),
                    if (item.groupName != 'Personal')
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          item.isPaidByMe
                              ? 'Your share: ${DateHelpers.formatCurrency(item.myShareAmount)}'
                              : 'Paid by ${item.payerName ?? 'Member'}',
                          style: TextStyle(
                            fontSize: 11,
                            color: item.isPaidByMe ? AppColors.primary : AppColors.textTertiary,
                            fontWeight: item.isPaidByMe ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                  ] else ...[
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.subtitle ?? 'Settlement',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          ' • ${DateHelpers.formatDayMonth(item.date)}',
                          style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Right Column: Amount & Tag Pill
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amountText,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: amountColor,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: tagBgColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    tagText,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: tagTextColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
