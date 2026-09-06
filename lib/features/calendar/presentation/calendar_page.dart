import 'package:flutter/material.dart';
import '../../../core/utils/haptic_helper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:expense_manager/app/theme/theme_provider.dart';
import 'package:intl/intl.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/utils/date_helpers.dart';
import '../../expenses/data/expense_repository.dart';
import '../../expenses/presentation/add_expense/add_expense_options_sheet.dart';
import '../../auth/data/auth_repository.dart';
import '../../../shared/widgets/animation_helpers.dart';
import '../../../shared/widgets/skeleton_loading_card.dart';
import 'widgets/calendar_expense_card.dart';
import '../../expenses/domain/expense_model.dart';
import '../../groups/data/group_repository.dart';
import '../../settlement/presentation/settlement_page.dart';

/// Provider for current month in calendar view.
final calendarMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});

/// Provider for selected date in calendar view.
final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

class DailySummary {
  final double total;
  final double userShare;
  final int items;
  const DailySummary({
    required this.total,
    required this.userShare,
    required this.items,
  });
}

final dailySummaryProvider = FutureProvider.family<DailySummary, DateTime>((
  ref,
  date,
) async {
  final expenses = await ref.watch(
    monthlyExpensesProvider(DateTime(date.year, date.month, 1)).future,
  );
  final dayExpenses = expenses
      .where((e) => DateHelpers.isSameDay(e.expenseDate, date))
      .toList();

  final currentUser = ref.watch(authStateProvider).valueOrNull;

  double total = 0;
  double userShare = 0;

  // Separate personal and group expenses
  final groupExpenses = <Expense>[];
  for (final e in dayExpenses) {
    total += e.amount;
    if (e.isPersonal) {
      if (currentUser != null && e.userId == currentUser.id) {
        userShare += e.amount;
      }
    } else {
      groupExpenses.add(e);
    }
  }
  // Batch fetch all splits in parallel instead of N+1 sequential calls
  if (groupExpenses.isNotEmpty && currentUser != null) {
    final repo = ref.read(expenseRepositoryProvider);
    final allSplitsFutures = groupExpenses.map((e) => repo.getExpenseSplits(e.id));
    final allSplitsResults = await Future.wait(allSplitsFutures);

    for (final splits in allSplitsResults) {
      final mySplit = splits
          .where((s) => s.userId == currentUser.id)
          .firstOrNull;
      if (mySplit != null) {
        userShare += mySplit.amountOwed;
      }
    }
  }

  return DailySummary(
    total: total,
    userShare: userShare,
    items: dayExpenses.length,
  );
});

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  @override
  void initState() {
    super.initState();
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Color _getExpenseColor(Expense expense, Map<String, GroupBalanceData> groupBalancesMap) {
    bool isSettled = expense.isSettled;
    if (!isSettled && expense.isGroup && expense.groupId != null) {
      final b = groupBalancesMap[expense.groupId];
      if (b != null) {
        isSettled = b.isExpenseFullySettled(expense);
      }
    }

    if (isSettled) {
      return const Color(0xFF22C55E); // Green (Settled)
    } else if (expense.isGroup) {
      return const Color(0xFFF97316); // Orange (Group)
    } else {
      return const Color(0xFF3B82F6); // Blue (Personal)
    }
  }

  Widget _buildSummaryCard(String title, double value, {bool isCount = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F6F6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isCount
                  ? value.toInt().toString()
                  : DateHelpers.formatCurrency(value),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCompactAmount(double val) {
    if (val >= 1000) {
      double kVal = val / 1000;
      return '₹${kVal.toStringAsFixed(kVal % 1 == 0 ? 0 : 1)}k';
    }
    return '₹${val.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    final currentMonth = ref.watch(calendarMonthProvider);
    final selectedDate = ref.watch(selectedDateProvider);
    final today = DateTime.now();

    final daysInMonth = DateHelpers.daysInMonth(currentMonth);
    final firstDayOfMonth = DateTime(currentMonth.year, currentMonth.month, 1);
    final startOffset = firstDayOfMonth.weekday % 7;

    final prevMonth = DateHelpers.previousMonth(currentMonth);
    final prevDaysCount = DateHelpers.daysInMonth(prevMonth);

    final expensesAsync = ref.watch(monthlyExpensesProvider(currentMonth));
    final userState = ref.watch(authStateProvider);
    final displayName = userState.valueOrNull?.name ?? 'User';

    final userGroups = ref.watch(userGroupsProvider).valueOrNull ?? [];
    final Map<String, GroupBalanceData> groupBalancesMap = {};
    for (final g in userGroups) {
      final b = ref.watch(groupBalancesProvider(g.id)).valueOrNull;
      if (b != null) {
        groupBalancesMap[g.id] = b;
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.surface,
        backgroundColor: AppColors.textPrimary,
        strokeWidth: 3,
        onRefresh: () async {
          ref.invalidate(monthlyExpensesProvider(currentMonth));
          ref.invalidate(dailySummaryProvider(ref.read(selectedDateProvider)));
          await Future.delayed(const Duration(milliseconds: 600));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: 130,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome, $displayName',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Track your daily spending',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderLight, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.01),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.chevron_left,
                              color: AppColors.textPrimary,
                              size: 20,
                            ),
                            onPressed: () =>
                                ref.read(calendarMonthProvider.notifier).state =
                                    DateHelpers.previousMonth(currentMonth),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                DateHelpers.formatMonthYear(currentMonth),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              if (currentMonth.year != today.year || currentMonth.month != today.month) ...[
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () {
                                    HapticHelper.lightTap();
                                    ref.read(calendarMonthProvider.notifier).state = DateTime(today.year, today.month, 1);
                                    ref.read(selectedDateProvider.notifier).state = DateTime.now();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                                    ),
                                    child: Text(
                                      'Today',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.chevron_right,
                              color: AppColors.textPrimary,
                              size: 20,
                            ),
                            onPressed: () =>
                                ref.read(calendarMonthProvider.notifier).state =
                                    DateHelpers.nextMonth(currentMonth),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 4,
                      ),
                      child: Row(
                        children:
                            ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT']
                                .map(
                                  (day) => Expanded(
                                    child: Center(
                                      child: Text(
                                        day,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textSecondary,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Divider(color: AppColors.borderLight, height: 1),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: expensesAsync.when(
                        skipLoadingOnReload: true,
                        skipLoadingOnRefresh: true,
                        data: (expenses) {
                          return LayoutBuilder(
                            builder: (context, constraints) {
                              final double totalWidth = constraints.maxWidth;
                              const double crossAxisSpacing = 6.0;
                              const int crossAxisCount = 7;
                              final double cellWidth = (totalWidth - (crossAxisCount - 1) * crossAxisSpacing) / crossAxisCount;
                              const double desiredHeight = 60.0; // Clean normal height for a balanced capsule shape
                              final double calculatedAspectRatio = cellWidth / desiredHeight;

                              return GridView.builder(
                                key: ValueKey<int>(
                                  currentMonth.month + currentMonth.year * 12,
                                ),
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  childAspectRatio: calculatedAspectRatio,
                                  crossAxisSpacing: crossAxisSpacing,
                                  mainAxisSpacing: 4,
                                ),
                                itemCount: 42,
                                itemBuilder: (context, index) {
                                  DateTime cellDate;
                                  bool isCurrentMonthDay = true;
                                  if (index < startOffset) {
                                    cellDate = DateTime(
                                      prevMonth.year,
                                      prevMonth.month,
                                      prevDaysCount - startOffset + index + 1,
                                    );
                                    isCurrentMonthDay = false;
                                  } else if (index >= startOffset + daysInMonth) {
                                    final nextMonthDate = DateHelpers.nextMonth(
                                      currentMonth,
                                    );
                                    cellDate = DateTime(
                                      nextMonthDate.year,
                                      nextMonthDate.month,
                                      index - startOffset - daysInMonth + 1,
                                    );
                                    isCurrentMonthDay = false;
                                  } else {
                                    cellDate = DateTime(
                                      currentMonth.year,
                                      currentMonth.month,
                                      index - startOffset + 1,
                                    );
                                  }

                                  final isToday = DateHelpers.isSameDay(
                                    cellDate,
                                    today,
                                  );
                                  final isSelected = DateHelpers.isSameDay(
                                    cellDate,
                                    selectedDate,
                                  );
                                  final dayExpenses = expenses
                                      .where(
                                        (e) => DateHelpers.isSameDay(
                                          e.expenseDate,
                                          cellDate,
                                        ),
                                      )
                                      .toList();
                                  final totalSpent = dayExpenses.fold<double>(
                                    0,
                                    (sum, e) => sum + e.amount,
                                  );
                                  final Set<Color> dotColors = {};
                                  for (var e in dayExpenses) {
                                    dotColors.add(_getExpenseColor(e, groupBalancesMap));
                                  }

                                  return GestureDetector(
                                    onTap: () {
                                      HapticHelper.lightTap();
                                      ref.read(selectedDateProvider.notifier).state = cellDate;
                                      if (!isCurrentMonthDay) {
                                        ref
                                            .read(
                                              calendarMonthProvider.notifier,
                                            )
                                            .state = DateTime(
                                          cellDate.year,
                                          cellDate.month,
                                          1,
                                        );
                                      }
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 150,
                                      ),
                                      padding: const EdgeInsets.only(
                                        top: 4.0,
                                        bottom: 4.0,
                                        left: 2.0,
                                        right: 2.0,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppColors.surfaceHover
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                        border: isToday
                                            ? Border.all(
                                                color: AppColors.textPrimary,
                                                width: 2.0,
                                              )
                                            : null,
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            '${cellDate.day}',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: isCurrentMonthDay
                                                  ? AppColors.textPrimary
                                                  : AppColors.textDisabled,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          SizedBox(
                                            height: 11,
                                            child: (totalSpent > 0 && isCurrentMonthDay)
                                                ? FittedBox(
                                                    fit: BoxFit.scaleDown,
                                                    child: Text(
                                                      _formatCompactAmount(
                                                        totalSpent,
                                                      ),
                                                      style: TextStyle(
                                                        fontSize: 9,
                                                        fontWeight:
                                                            FontWeight.w900,
                                                        color: isSelected
                                                            ? AppColors.textPrimary
                                                            : AppColors.textSecondary,
                                                      ),
                                                    ),
                                                  )
                                                : const SizedBox.shrink(),
                                          ),
                                          const SizedBox(height: 4),
                                          SizedBox(
                                            height: 5,
                                            child: dotColors.isNotEmpty
                                                ? Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.center,
                                                    children: dotColors
                                                        .map(
                                                          (color) => Container(
                                                            margin:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                              horizontal: 0.8,
                                                            ),
                                                            width: 4.5,
                                                            height: 4.5,
                                                            decoration:
                                                                BoxDecoration(
                                                              color: color,
                                                              shape: BoxShape
                                                                  .circle,
                                                            ),
                                                          ),
                                                        )
                                                        .toList(),
                                                  )
                                                : const SizedBox.shrink(),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                        loading: () => const SizedBox(
                          height: 180,
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        error: (e, st) => SizedBox(
                          height: 180,
                          child: Center(
                            child: Text(
                              'Error: $e',
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Divider(color: AppColors.borderLight, height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildLegendItem(const Color(0xFF3B82F6), 'Personal'),
                          const SizedBox(width: 16),
                          _buildLegendItem(const Color(0xFFF97316), 'Group'),
                          const SizedBox(width: 16),
                          _buildLegendItem(const Color(0xFF22C55E), 'Settled'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderLight, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('EEEE').format(selectedDate),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              DateFormat('dd MMMM yyyy').format(selectedDate),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: Colors.transparent,
                              isScrollControlled: true,
                              useRootNavigator: true,
                              builder: (_) => AddExpenseOptionsSheet(
                                initialDate: selectedDate,
                              ),
                            );
                          },
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.primary,
                                  const Color(0xFF41A5FF),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.35),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.add_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    expensesAsync.when(
                      data: (expenses) {
                        final dayExpenses = expenses
                            .where(
                              (e) => DateHelpers.isSameDay(
                                e.expenseDate,
                                selectedDate,
                              ),
                            )
                            .toList();
                        if (dayExpenses.isEmpty) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.xl,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.08),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.receipt_long_rounded,
                                    size: 28,
                                    color: AppColors.primary.withValues(alpha: 0.6),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No expenses on this day.',
                                  style: TextStyle(
                                    color: AppColors.textTertiary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return ref
                            .watch(dailySummaryProvider(selectedDate))
                            .when(
                              skipLoadingOnReload: true,
                              skipLoadingOnRefresh: true,
                              data: (summary) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        _buildSummaryCard(
                                          'Total',
                                          summary.total,
                                        ),
                                        const SizedBox(width: 6),
                                        _buildSummaryCard(
                                          'Your Share',
                                          summary.userShare,
                                        ),
                                        const SizedBox(width: 6),
                                        _buildSummaryCard(
                                          'Items',
                                          summary.items.toDouble(),
                                          isCount: true,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    ListView.separated(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      itemCount: dayExpenses.length,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(height: 8),
                                      itemBuilder: (context, index) =>
                                          StaggeredListItem(
                                            index: index,
                                            child: CalendarExpenseCard(
                                              expense: dayExpenses[index],
                                            ),
                                          ),
                                    ),
                                  ],
                                );
                              },
                              loading: () => const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: SkeletonList(itemCount: 1),
                              ),
                              error: (_, __) => const Center(
                                child: Text('Error loading summary'),
                              ),
                            );
                      },
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: SkeletonList(itemCount: 2),
                      ),
                      error: (e, st) => Center(
                        child: Text(
                          'Error: $e',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
