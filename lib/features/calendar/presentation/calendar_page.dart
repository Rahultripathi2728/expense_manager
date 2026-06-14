import 'package:flutter/material.dart';
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

/// Provider for current month in calendar view.
final calendarMonthProvider = StateProvider<DateTime>((ref) => DateTime.now());

class DailySummary {
  final double total;
  final double userShare;
  final int items;
  const DailySummary({required this.total, required this.userShare, required this.items});
}

final dailySummaryProvider = FutureProvider.family<DailySummary, DateTime>((ref, date) async {
  final expenses = await ref.watch(monthlyExpensesProvider(DateTime(date.year, date.month, 1)).future);
  final dayExpenses = expenses.where((e) => DateHelpers.isSameDay(e.expenseDate, date)).toList();
  
  final currentUser = ref.watch(authStateProvider).valueOrNull;
  
  double total = 0;
  double userShare = 0;
  
  for (final e in dayExpenses) {
    total += e.amount;
    if (e.isPersonal) {
      if (currentUser != null && e.userId == currentUser.id) {
        userShare += e.amount;
      }
    } else {
      final splits = await ref.read(expenseRepositoryProvider).getExpenseSplits(e.id);
      if (currentUser != null) {
        final mySplit = splits.where((s) => s.userId == currentUser.id).firstOrNull;
        if (mySplit != null) {
          userShare += mySplit.amountOwed;
        }
      }
    }
  }
  
  return DailySummary(total: total, userShare: userShare, items: dayExpenses.length);
});

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
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

  Color _getExpenseColor(dynamic expense) {
    if (expense.isSettled) {
      return const Color(0xFF22C55E); // Green (Settled)
    } else if (expense.expenseType == 'group') {
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
              isCount ? value.toInt().toString() : DateHelpers.formatCurrency(value),
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

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    final currentMonth = ref.watch(calendarMonthProvider);
    final today = DateTime.now();

    final daysInMonth = DateHelpers.daysInMonth(currentMonth);
    final firstDayOfMonth = DateTime(currentMonth.year, currentMonth.month, 1);
    final startOffset = firstDayOfMonth.weekday % 7;

    final prevMonth = DateHelpers.previousMonth(currentMonth);
    final prevDaysCount = DateHelpers.daysInMonth(prevMonth);

    final expensesAsync = ref.watch(monthlyExpensesProvider(currentMonth));
    final userState = ref.watch(authStateProvider);
    final displayName = userState.valueOrNull?.name ?? 'User';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(left: AppSpacing.lg, right: AppSpacing.lg, top: AppSpacing.lg, bottom: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Welcome, $displayName', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.5)),
            const SizedBox(height: 4),
            Text('Track your daily spending', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.xl),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderLight, width: 1),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.01), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(Icons.chevron_left, color: AppColors.textPrimary),
                          onPressed: () => ref.read(calendarMonthProvider.notifier).state = DateHelpers.previousMonth(currentMonth),
                        ),
                        Text(DateHelpers.formatMonthYear(currentMonth), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        IconButton(
                          icon: Icon(Icons.chevron_right, color: AppColors.textPrimary),
                          onPressed: () => ref.read(calendarMonthProvider.notifier).state = DateHelpers.nextMonth(currentMonth),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                    child: Row(
                      children: ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'].map((day) => Expanded(
                        child: Center(child: Text(day, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.5))),
                      )).toList(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Divider(color: AppColors.borderLight),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: expensesAsync.when(
                      skipLoadingOnReload: true,
                      skipLoadingOnRefresh: true,
                      data: (expenses) {
                        return AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: GridView.builder(
                            key: ValueKey<int>(currentMonth.month + currentMonth.year * 12),
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 0.9, crossAxisSpacing: 4, mainAxisSpacing: 4),
                            itemCount: 42,
                            itemBuilder: (context, index) {
                              DateTime cellDate;
                              bool isCurrentMonthDay = true;
                              if (index < startOffset) {
                                cellDate = DateTime(prevMonth.year, prevMonth.month, prevDaysCount - startOffset + index + 1);
                                isCurrentMonthDay = false;
                              } else if (index >= startOffset + daysInMonth) {
                                final nextMonthDate = DateHelpers.nextMonth(currentMonth);
                                cellDate = DateTime(nextMonthDate.year, nextMonthDate.month, index - startOffset - daysInMonth + 1);
                                isCurrentMonthDay = false;
                              } else {
                                cellDate = DateTime(currentMonth.year, currentMonth.month, index - startOffset + 1);
                              }

                              final isToday = DateHelpers.isSameDay(cellDate, today);
                              final isSelected = DateHelpers.isSameDay(cellDate, _selectedDate);
                              final dayExpenses = expenses.where((e) => DateHelpers.isSameDay(e.expenseDate, cellDate)).toList();
                              final totalSpent = dayExpenses.fold<double>(0, (sum, e) => sum + e.amount);
                              final Set<Color> dotColors = {};
                              for (var e in dayExpenses) {
                                dotColors.add(_getExpenseColor(e));
                              }

                              return GestureDetector(
                                onTap: () {
                                  setState(() => _selectedDate = cellDate);
                                  if (!isCurrentMonthDay) ref.read(calendarMonthProvider.notifier).state = DateTime(cellDate.year, cellDate.month, 1);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFFEBEBEB) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    border: isToday ? Border.all(color: AppColors.textPrimary, width: 1.8) : null,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '${cellDate.day}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.w500,
                                          color: isCurrentMonthDay ? AppColors.textPrimary : Colors.grey.shade300,
                                        ),
                                      ),
                                      if (isSelected && totalSpent > 0) ...[
                                        const SizedBox(height: 2),
                                        Text('?${totalSpent.round()}', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                      ],
                                      if (dotColors.isNotEmpty) ...[
                                        const SizedBox(height: 3),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: dotColors.map((color) => Container(
                                            margin: const EdgeInsets.symmetric(horizontal: 1.5),
                                            width: 5, height: 5,
                                            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                                          )).toList(),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                      loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                      error: (e, st) => SizedBox(height: 200, child: Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red)))),
                    ),
                  ),
                  Divider(color: AppColors.borderLight),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildLegendItem(const Color(0xFF3B82F6), 'Personal'), const SizedBox(width: 24),
                        _buildLegendItem(const Color(0xFFF97316), 'Group'), const SizedBox(width: 24),
                        _buildLegendItem(const Color(0xFF22C55E), 'Settled'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.borderLight, width: 1)),
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
                          Text(DateFormat('EEEE').format(_selectedDate), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                          Text(DateFormat('dd MMMM yyyy').format(_selectedDate), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
                        ],
                      ),
                      GestureDetector(
                        onTap: () {
                          showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true, useRootNavigator: true, builder: (_) => const AddExpenseOptionsSheet());
                        },
                        child: Container(
                          width: 44, height: 44, decoration: BoxDecoration(color: AppColors.textPrimary, borderRadius: BorderRadius.circular(12)),
                          child: Icon(Icons.add, color: AppColors.surface, size: 24),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  expensesAsync.when(
                    data: (expenses) {
                      final dayExpenses = expenses.where((e) => DateHelpers.isSameDay(e.expenseDate, _selectedDate)).toList();
                      if (dayExpenses.isEmpty) {
                        return Container(
                          width: double.infinity, padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long_outlined, size: 40, color: AppColors.border),
                              const SizedBox(height: 12),
                              Text('No expenses on this day.', style: TextStyle(color: AppColors.textTertiary, fontSize: 14)),
                            ],
                          ),
                        );
                      }
                      return ref.watch(dailySummaryProvider(_selectedDate)).when(
                        skipLoadingOnReload: true,
                        skipLoadingOnRefresh: true,
                        data: (summary) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  _buildSummaryCard('Total', summary.total), const SizedBox(width: 8),
                                  _buildSummaryCard('Your Share', summary.userShare), const SizedBox(width: 8),
                                  _buildSummaryCard('Items', summary.items.toDouble(), isCount: true),
                                ],
                              ),
                              const SizedBox(height: 16),
                              ListView.separated(
                                shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: dayExpenses.length, separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (context, index) => StaggeredListItem(index: index, child: CalendarExpenseCard(expense: dayExpenses[index])),
                              ),
                            ],
                          );
                        },
                        loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: SkeletonList(itemCount: 2)),
                        error: (_, __) => const Center(child: Text('Error loading summary')),
                      );
                    },
                    loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: SkeletonList(itemCount: 3)),
                    error: (e, st) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

