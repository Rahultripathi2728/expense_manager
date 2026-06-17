import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:expense_manager/app/theme/theme_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../shared/services/categorize_service.dart';
import '../../../shared/widgets/animation_helpers.dart';
import '../../../shared/widgets/skeleton_loading_card.dart';
import '../../expenses/data/expense_repository.dart';
import '../../auth/data/auth_repository.dart';
import '../../../core/utils/date_helpers.dart';

class AnalyticsPage extends ConsumerWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(themeProvider);
    final now = DateTime.now();
    // Use a stable current month (1st day of month) for analytics to prevent infinite rebuilds
    final currentMonth = DateTime(now.year, now.month);
    final expensesAsync = ref.watch(monthlyExpensesProvider(currentMonth));
    final splitsAsync = ref.watch(userSplitsProvider);
    final currentUser = ref.watch(authStateProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: expensesAsync.when(
        loading: () =>
            const Padding(padding: EdgeInsets.all(AppSpacing.lg), child: SkeletonList(itemCount: 3)),
        error: (err, _) => Center(
          child: Text('Error: $err', style: const TextStyle(color: Colors.red)),
        ),
        data: (expenses) {
          final userSplits = splitsAsync.valueOrNull ?? [];
          final myUserId = currentUser?.id ?? '';

          // Calculate category sums
          final Map<String, double> categorySums = {};
          final Map<int, double> dailySums = {};

          for (final exp in expenses) {
            double amt = 0.0;
            if (exp.isPersonal) {
              amt = exp.amount;
            } else {
              final match = userSplits
                  .where((s) => s.expenseId == exp.id && s.userId == myUserId)
                  .toList();
              if (match.isNotEmpty) amt = match.first.amountOwed;
            }

            if (amt > 0) {
              categorySums[exp.category] =
                  (categorySums[exp.category] ?? 0.0) + amt;
              final day = exp.expenseDate.day;
              dailySums[day] = (dailySums[day] ?? 0.0) + amt;
            }
          }

          final totalSpent = categorySums.values.fold<double>(
            0.0,
            (a, b) => a + b,
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  'Analytics',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Your spending overview',
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Total Spent Card with scale-in
                ScaleIn(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.textPrimary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'TOTAL SPENT THIS MONTH',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          DateHelpers.formatCurrency(totalSpent),
                          style: TextStyle(
                            color: AppColors.surface,
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),

                Text(
                  'Category Breakdown',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                if (categorySums.isEmpty)
                  Center(
                    child: Text(
                      'No expenses to analyze yet.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                else ...[
                  // Pie Chart with fade-slide
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 200),
                    child: SizedBox(
                      height: 220,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 50,
                          sections: categorySums.entries.map((e) {
                            final color = AppColors.categoryColor(e.key);
                            final pct = (e.value / totalSpent) * 100;
                            return PieChartSectionData(
                              color: color,
                              value: e.value,
                              title: pct > 5
                                  ? '${pct.toStringAsFixed(0)}%'
                                  : '',
                              radius: 40,
                              titleStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.surface,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Category Legend
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: categorySums.entries.map((e) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.categoryColor(e.key),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            CategorizeService.displayName(e.key),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  Text(
                    'Daily Trends',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Bar Chart with fade-slide
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 400),
                    child: SizedBox(
                      height: 240,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: dailySums.isEmpty
                              ? 100
                              : dailySums.values.reduce(
                                      (a, b) => a > b ? a : b,
                                    ) *
                                    1.2,
                          barTouchData: BarTouchData(enabled: false),
                          titlesData: FlTitlesData(
                            show: true,
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget:
                                    (double value, TitleMeta meta) {
                                      final intDay = value.toInt();
                                      if (intDay % 5 == 0 || intDay == 1) {
                                        return Text(
                                          intDay.toString(),
                                          style: TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 10,
                                          ),
                                        );
                                      }
                                      return const SizedBox.shrink();
                                    },
                              ),
                            ),
                            leftTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          gridData: const FlGridData(show: false),
                          borderData: FlBorderData(show: false),
                          barGroups: List.generate(
                            DateHelpers.daysInMonth(now),
                            (i) => BarChartGroupData(
                              x: i + 1,
                              barRods: [
                                BarChartRodData(
                                  toY: dailySums[i + 1] ?? 0.0,
                                  color: AppColors.textPrimary,
                                  width: 8,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 100),
              ],
            ),
          );
        },
      ),
    );
  }
}
