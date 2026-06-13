import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:expense_manager/app/theme/theme_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../shared/widgets/animation_helpers.dart';
import '../../../core/utils/date_helpers.dart';
import '../../../shared/services/categorize_service.dart';
import '../data/expense_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../domain/expense_model.dart';
import '../domain/expense_split_model.dart';
import '../../profile/domain/profile_model.dart';
import '../../auth/data/auth_repository.dart';
import '../../../shared/widgets/skeleton_loading_card.dart';

// Providers to track active states
final expensesTabProvider = StateProvider<int>((ref) => 0);
final analyticsMonthProvider = StateProvider<DateTime>((ref) => DateTime.now());
final chartTabProvider = StateProvider<int>(
  (ref) => 0,
); // 0 = Daily Trend, 1 = Categories

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
  ) {
    final controller = TextEditingController(
      text: profile.monthlyBudget.toStringAsFixed(0),
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: AppColors.surface,
        title: const Text(
          'Edit Monthly Budget',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Budget Amount (₹)',
            hintText: 'Enter new monthly budget',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.textPrimary,
              foregroundColor: AppColors.surface,
            ),
            onPressed: () async {
              final val = double.tryParse(controller.text) ?? 0.0;
              final updated = profile.copyWith(monthlyBudget: val);
              await ref.read(profileRepositoryProvider).updateProfile(updated);
              ref.invalidate(currentProfileProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
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
    final currentUser = ref.watch(authStateProvider).valueOrNull;
    final chartTab = ref.watch(chartTabProvider);
    final userSplits = splitsAsync.valueOrNull ?? [];
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
                    Icons.chevron_left,
                    color: AppColors.textPrimary,
                    size: 20,
                  ),
                  onPressed: () =>
                      ref.read(analyticsMonthProvider.notifier).state =
                          DateHelpers.previousMonth(month),
                ),
              ),
              const SizedBox(width: 8),
              // Current month display
              Expanded(
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
                        color: AppColors.textPrimary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateHelpers.formatMonthYear(month),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (DateHelpers.isCurrentMonth(month)) ...[
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
                    Icons.chevron_right,
                    color: AppColors.textPrimary,
                    size: 20,
                  ),
                  onPressed: () =>
                      ref.read(analyticsMonthProvider.notifier).state =
                          DateHelpers.nextMonth(month),
                ),
              ),
              const SizedBox(width: 8),
              // Filter
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.borderLight),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: Icon(Icons.tune, color: AppColors.textPrimary, size: 20),
                  onPressed: () {},
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          expensesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.only(top: 20),
              child: SkeletonList(itemCount: 4),
            ),
            error: (err, _) => Center(
              child: Text(
                'Error loading expenses: $err',
                style: const TextStyle(color: Colors.red),
              ),
            ),
            data: (expenses) {

              final personalTotal = expenses
                  .where((e) => e.isPersonal)
                  .fold<double>(0.0, (sum, e) => sum + e.amount);
              double groupShareTotal = 0.0;
              for (final e in expenses.where((e) => e.isGroup)) {
                final match = userSplits
                    .where((s) => s.expenseId == e.id && s.userId == myUserId)
                    .toList();
                if (match.isNotEmpty) {
                  groupShareTotal += match.first.amountOwed;
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
                        final budget = profile?.monthlyBudget ?? 10000.0;
                        final percentage = budget > 0
                            ? (totalSpent / budget) * 100
                            : 0.0;
                        final remaining = budget - totalSpent;

                        return Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: AppColors.textPrimary,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'MONTHLY BUDGET',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        DateHelpers.formatCurrency(budget),
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.surface,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'SPENT',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        DateHelpers.formatCurrency(totalSpent),
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.surface,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: budget > 0
                                      ? (totalSpent / budget).clamp(0.0, 1.0)
                                      : 0.0,
                                  minHeight: 7,
                                  backgroundColor: AppColors.borderLight,
                                  color: percentage >= 90
                                      ? Colors.red
                                      : percentage >= 60
                                      ? Colors.amber
                                      : const Color(0xFF22C55E),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${percentage.toStringAsFixed(0)}% used',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    remaining >= 0
                                        ? '${DateHelpers.formatCurrency(remaining)} remaining'
                                        : '${DateHelpers.formatCurrency(-remaining)} over budget',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (profile != null)
                                GestureDetector(
                                  onTap: () => _showEditBudgetDialog(
                                    context,
                                    ref,
                                    profile,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Edit Budget',
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Icon(
                                        Icons.chevron_right,
                                        color: AppColors.textSecondary,
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Personal and Group breakdown cards with fade-slide
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 200),
                    child: Column(
                      children: [
                        // Personal Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.borderLight),
                          ),
                          child: Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Personal',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    DateHelpers.formatCurrency(personalTotal),
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.account_balance_wallet_outlined,
                                  color: AppColors.textPrimary,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Group Share Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.borderLight),
                          ),
                          child: Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'My Share (Group)',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    DateHelpers.formatCurrency(groupShareTotal),
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.people_outline,
                                  color: AppColors.textPrimary,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Total Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.borderLight),
                          ),
                          child: Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Total',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    DateHelpers.formatCurrency(totalSpent),
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE2FBE7),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.trending_up,
                                  color: Color(0xFF22C55E),
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Chart Tab switch pills
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F3F3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                ref.read(chartTabProvider.notifier).state = 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: chartTab == 0
                                    ? AppColors.surface
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Daily Trend',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: chartTab == 0
                                      ? AppColors.textPrimary
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                ref.read(chartTabProvider.notifier).state = 1,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: chartTab == 1
                                    ? AppColors.surface
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Categories',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: chartTab == 1
                                      ? AppColors.textPrimary
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Render Selected Chart
                  if (chartTab == 0)
                    DailyTrendChart(
                      expenses: expenses,
                      userSplits: userSplits,
                      currentUserId: myUserId ?? '',
                      month: month,
                    )
                  else
                    CategoryDistributionList(
                      expenses: expenses,
                      userSplits: userSplits,
                      currentUserId: myUserId ?? '',
                    ),

                  const SizedBox(height: AppSpacing.xl),

                  // Recent Expenses Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Expenses',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => context.push('/expenses/view-all'),
                        icon: const SizedBox(),
                        label: Row(
                          children: [
                            Text(
                              'View All',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Recent Expenses List
                  if (expenses.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      alignment: Alignment.center,
                      child: Text(
                        'No expenses recorded.',
                        style: TextStyle(color: AppColors.textTertiary),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: expenses.length > 5 ? 5 : expenses.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, idx) {
                        final e = expenses[idx];
                        final isGrp = e.expenseType == 'group';
                        final dotColor = e.isSettled
                            ? const Color(0xFF22C55E)
                            : isGrp
                            ? const Color(0xFFF97316)
                            : const Color(0xFF3B82F6);

                        double shareAmt = e.amount;
                        if (isGrp) {
                          final match = userSplits
                              .where(
                                (s) =>
                                    s.expenseId == e.id && s.userId == myUserId,
                              )
                              .toList();
                          shareAmt = match.isNotEmpty
                              ? match.first.amountOwed
                              : e.amount;
                        }
                        return StaggeredListItem(
                          index: idx,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppColors.borderLight,
                                width: 1,
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: ListTile(
                                onTap: () =>
                                    context.push('/expense-detail', extra: e),
                                leading: CircleAvatar(
                                  backgroundColor: dotColor.withValues(
                                    alpha: 0.1,
                                  ),
                                  child: Text(
                                    CategorizeService.iconForCategory(
                                      e.category,
                                    ),
                                    style: const TextStyle(fontSize: 18),
                                  ),
                                ),
                                title: Text(
                                  e.description,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                subtitle: Row(
                                  children: [
                                    Text(
                                      DateHelpers.formatDayMonth(e.expenseDate),
                                      style: TextStyle(
                                        color: AppColors.textTertiary,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (isGrp && e.isSettled)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE2FBE7),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: const Text(
                                          'Settled',
                                          style: TextStyle(
                                            color: Color(0xFF22C55E),
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      DateHelpers.formatCurrency(e.amount),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    if (isGrp)
                                      Text(
                                        'Share: ${DateHelpers.formatCurrency(shareAmt)}',
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 11,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
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
}

class DailyTrendChart extends StatelessWidget {
  final List<Expense> expenses;
  final List<ExpenseSplit> userSplits;
  final String currentUserId;
  final DateTime month;

  const DailyTrendChart({
    super.key,
    required this.expenses,
    required this.userSplits,
    required this.currentUserId,
    required this.month,
  });

  @override
  Widget build(BuildContext context) {
    final days = DateHelpers.daysInMonth(month);
    final List<FlSpot> personalSpots = [];
    final List<FlSpot> groupSpots = [];

    for (int d = 1; d <= days; d++) {
      final dayDate = DateTime(month.year, month.month, d);
      final dayExps = expenses
          .where((e) => DateHelpers.isSameDay(e.expenseDate, dayDate))
          .toList();

      double personalDay = 0.0;
      double groupDay = 0.0;

      for (final e in dayExps) {
        if (e.isPersonal) {
          personalDay += e.amount;
        } else {
          final match = userSplits
              .where((s) => s.expenseId == e.id && s.userId == currentUserId)
              .toList();
          if (match.isNotEmpty) {
            groupDay += match.first.amountOwed;
          }
        }
      }
      personalSpots.add(FlSpot(d.toDouble(), personalDay));
      groupSpots.add(FlSpot(d.toDouble(), groupDay));
    }

    double maxVal = 1000;
    for (final spot in personalSpots) {
      if (spot.y > maxVal) maxVal = spot.y;
    }
    for (final spot in groupSpots) {
      if (spot.y > maxVal) maxVal = spot.y;
    }
    maxVal = (maxVal / 1000).ceil() * 1000.0; // round to next 1k

    return Column(
      children: [
        Container(
          height: 220,
          padding: const EdgeInsets.only(right: 16, top: 16, bottom: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F3F3),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.bar_chart,
                          size: 16,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Daily Spending',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: true,
                      horizontalInterval: maxVal > 0 ? maxVal / 4 : 1000,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: AppColors.surfaceVariant,
                        strokeWidth: 1,
                        dashArray: [5, 5],
                      ),
                      getDrawingVerticalLine: (value) => FlLine(
                        color: AppColors.surfaceVariant,
                        strokeWidth: 1,
                        dashArray: [5, 5],
                      ),
                    ),
                    titlesData: FlTitlesData(
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 32,
                          interval: maxVal / 4 > 0 ? maxVal / 4 : 1000,
                          getTitlesWidget: (val, _) {
                            if (val == 0) return const SizedBox();
                            if (val >= 1000) {
                              return Text(
                                '${(val / 1000).toStringAsFixed(0)}k',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondary,
                                ),
                              );
                            }
                            return Text(
                              val.toStringAsFixed(0),
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                              ),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (val, _) {
                            final intDay = val.toInt();
                            if (intDay == 1 ||
                                intDay == 5 ||
                                intDay == 10 ||
                                intDay == 15 ||
                                intDay == 20 ||
                                intDay == 25 ||
                                intDay == days) {
                              return Text(
                                intDay.toString().padLeft(2, '0'),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondary,
                                ),
                              );
                            }
                            return const SizedBox();
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border(
                        bottom: BorderSide(
                          color: AppColors.textTertiary,
                          width: 2,
                        ),
                      ),
                    ),
                    minX: 1,
                    maxX: days.toDouble(),
                    minY: 0,
                    maxY: maxVal,
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (touchedSpot) => AppColors.surface,
                        tooltipRoundedRadius: 8,
                        tooltipBorder: BorderSide(color: AppColors.borderLight),
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((spot) {
                            final dateStr =
                                '${spot.x.toInt().toString().padLeft(2, '0')} ${DateFormat('MMM').format(month)}';
                            return LineTooltipItem(
                              '$dateStr\nTotal: ${DateHelpers.formatCurrency(spot.y)}',
                              TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            );
                          }).toList();
                        },
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: personalSpots,
                        isCurved: true,
                        color: AppColors.textPrimary,
                        barWidth: 2.2,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: AppColors.textPrimary.withValues(alpha: 0.04),
                        ),
                      ),
                      LineChartBarData(
                        spots: groupSpots,
                        isCurved: true,
                        color: AppColors.textTertiary,
                        barWidth: 2.2,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: Colors.grey.withValues(alpha: 0.04),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Legend
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.textPrimary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Personal',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.textTertiary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Group',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class CategoryDistributionList extends StatelessWidget {
  final List<Expense> expenses;
  final List<ExpenseSplit> userSplits;
  final String currentUserId;

  const CategoryDistributionList({
    super.key,
    required this.expenses,
    required this.userSplits,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final Map<String, double> categorySums = {};
    for (final exp in expenses) {
      double amt = 0.0;
      if (exp.isPersonal) {
        amt = exp.amount;
      } else {
        final matching = userSplits
            .where((s) => s.expenseId == exp.id && s.userId == currentUserId)
            .toList();
        amt = matching.isNotEmpty ? matching.first.amountOwed : 0.0;
      }
      categorySums[exp.category] = (categorySums[exp.category] ?? 0.0) + amt;
    }

    final sorted = categorySums.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final double total = categorySums.values.fold<double>(0.0, (a, b) => a + b);

    if (sorted.isEmpty) {
      return Container(
        height: 100,
        alignment: Alignment.center,
        child: Text(
          'No category details available',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final entry = sorted[index];
        final pct = total > 0 ? (entry.value / total) * 100 : 0.0;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.borderLight,
                child: Text(
                  CategorizeService.iconForCategory(entry.key),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      CategorizeService.displayName(entry.key),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: total > 0 ? entry.value / total : 0.0,
                      backgroundColor: AppColors.surfaceVariant,
                      color: AppColors.textPrimary,
                      minHeight: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    DateHelpers.formatCurrency(entry.value),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '${pct.toStringAsFixed(0)}%',
                    style: TextStyle(color: AppColors.textTertiary, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
