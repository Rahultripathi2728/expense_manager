import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/date_helpers.dart';
import '../../auth/data/auth_repository.dart';
import '../../expenses/domain/expense_model.dart';
import '../../expenses/presentation/utils/category_icon_helper.dart';
import '../../settlement/presentation/settlement_page.dart';
import '../../settlement/domain/settlement_model.dart';
import '../domain/group_model.dart';
import '../../profile/domain/profile_model.dart';
import 'group_detail_page.dart';
import '../../../shared/widgets/skeleton_loading_card.dart';
import '../../../shared/widgets/custom_error_widget.dart';

class GroupBalancesDetailPage extends ConsumerWidget {
  final String groupId;

  const GroupBalancesDetailPage({
    super.key,
    required this.groupId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupAsync = ref.watch(groupDetailProvider(groupId));
    final balancesAsync = ref.watch(groupBalancesProvider(groupId));
    final currentUser = ref.watch(authStateProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hisaab Breakdown',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            groupAsync.when(
              data: (group) => Text(
                group?.name ?? 'Group Balances',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: groupAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => CustomErrorWidget(
          error: err,
          message: err.toString(),
          onRetry: () {
            ref.invalidate(groupDetailProvider(groupId));
            ref.invalidate(groupBalancesProvider(groupId));
          },
        ),
        data: (group) {
          if (group == null) {
            return const Center(child: Text('Group not found'));
          }

          return balancesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: SkeletonExpenseCard(),
            ),
            error: (err, _) => CustomErrorWidget(
              error: err,
              message: err.toString(),
              onRetry: () => ref.invalidate(groupBalancesProvider(groupId)),
            ),
            data: (data) => _buildDetailContent(context, group, data, currentUser),
          );
        },
      ),
    );
  }

  Widget _buildDetailContent(
    BuildContext context,
    Group group,
    GroupBalanceData data,
    dynamic currentUser,
  ) {
    final myUserId = currentUser?.id ?? '';
    final members = data.profiles.values.toList();
    final activeExpenses = data.unsettledExpenses;
    final totalSpent = activeExpenses.fold<double>(0.0, (sum, e) => sum + e.amount);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top Hero Card ──
          _buildHeroHeader(group, totalSpent, members.length, data.unsettledExpensesCount),
          const SizedBox(height: 20),

          // ── Section 1: Excel Spreadsheet Matrix ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.table_chart_rounded, size: 18, color: Color(0xFF10B981)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Expense Matrix (Spreadsheet)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${activeExpenses.length} Bills',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Scroll horizontally to view each member\'s exact share and payment',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),

          _buildExcelMatrixTable(context, activeExpenses, members, data, totalSpent),
          const SizedBox(height: 24),

          // ── Section 2: Step-by-Step Hisaab Math ──
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.calculate_rounded, size: 18, color: Color(0xFF3B82F6)),
              ),
              const SizedBox(width: 8),
              Text(
                'Balance Calculation Breakdown',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Step-by-step arithmetic for expenses, consumption share, and settlements',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),

          _buildArithmeticHisaabCard(context, members, data, myUserId),
          const SizedBox(height: 24),

          // ── Section 3: Final Settlement Conclusion ──
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.check_circle_outline_rounded, size: 18, color: Color(0xFFF59E0B)),
              ),
              const SizedBox(width: 8),
              Text(
                'Final Settlement Conclusion',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Optimized minimum payment transfers to clear all remaining balances:',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),

          _buildFinalConclusionCard(context, data, group),
        ],
      ),
    );
  }

  Widget _buildHeroHeader(Group group, double totalSpent, int memberCount, int billCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surface,
            AppColors.surfaceVariant.withValues(alpha: 0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primary,
                            const Color(0xFF41A5FF),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          group.name.isNotEmpty ? group.name[0].toUpperCase() : 'G',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.name,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$memberCount Members • Active Cycle',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.25)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sync_rounded, size: 14, color: Color(0xFF10B981)),
                    SizedBox(width: 4),
                    Text(
                      'Live Hisaab',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Active Spent',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateHelpers.formatCurrency(totalSpent),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 36, color: AppColors.borderLight),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bills to Settle',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$billCount Bills',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExcelMatrixTable(
    BuildContext context,
    List<Expense> expenses,
    List<dynamic> members,
    GroupBalanceData data,
    double totalSpent,
  ) {
    if (expenses.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          children: [
            const Icon(Icons.check_circle_outline_rounded, size: 48, color: Color(0xFF10B981)),
            const SizedBox(height: 12),
            const Text(
              'All Expenses Settled!',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'No active bills currently pending settlement.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: DataTable(
          columnSpacing: 22,
          horizontalMargin: 16,
          headingRowColor: WidgetStateProperty.all(
            AppColors.surfaceVariant.withValues(alpha: 0.8),
          ),
          dataRowMinHeight: 48,
          dataRowMaxHeight: 56,
          border: TableBorder(
            horizontalInside: BorderSide(color: AppColors.borderLight, width: 0.8),
            verticalInside: BorderSide(color: AppColors.borderLight.withValues(alpha: 0.5), width: 0.6),
          ),
          columns: [
            const DataColumn(
              label: Text(
                '#',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            const DataColumn(
              label: Text(
                'Date',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            const DataColumn(
              label: Text(
                'Expense Description',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            const DataColumn(
              label: Text(
                'Paid By (Amount)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            ...members.map(
              (m) => DataColumn(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 11,
                      backgroundColor: AppColors.primary,
                      child: Text(
                        m.fullName.isNotEmpty ? m.fullName[0].toUpperCase() : 'U',
                        style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      m.fullName.split(' ').first,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ],
          rows: [
            // ── Rows for each active expense ──
            ...List.generate(expenses.length, (index) {
              final exp = expenses[index];
              final payer = data.profiles[exp.userId];
              final payerName = payer?.fullName.split(' ').first ?? 'User';
              final splits = data.splitsByExpense[exp.id] ?? [];
              final splitMap = {for (var s in splits) s.userId: s};
              final isEven = index % 2 == 0;

              return DataRow(
                color: WidgetStateProperty.all(
                  isEven ? AppColors.surface : AppColors.surfaceVariant.withValues(alpha: 0.25),
                ),
                cells: [
                  DataCell(
                    Text(
                      '${index + 1}',
                      style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                    ),
                  ),
                  DataCell(
                    Text(
                      DateHelpers.formatDayMonth(exp.expenseDate),
                      style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CategoryIconHelper.getIcon(exp.category),
                          size: 16,
                          color: AppColors.categoryColor(exp.category),
                        ),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 140),
                          child: Text(
                            exp.description,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$payerName: ₹${exp.amount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ),
                  ),
                  ...members.map((m) {
                    final split = splitMap[m.userId];
                    if (split == null || !split.isIncluded || split.amountOwed <= 0.01) {
                      return DataCell(
                        Center(
                          child: Text(
                            '—',
                            style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                          ),
                        ),
                      );
                    }
                    return DataCell(
                      Text(
                        '₹${split.amountOwed.toStringAsFixed(1)}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    );
                  }),
                ],
              );
            }),

            // ── TOTALS FOOTER ROW ──
            DataRow(
              color: WidgetStateProperty.all(
                AppColors.primary.withValues(alpha: 0.08),
              ),
              cells: [
                const DataCell(Text('Σ', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15))),
                const DataCell(Text('TOTAL', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13))),
                DataCell(
                  Text(
                    '${expenses.length} Items',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                  ),
                ),
                DataCell(
                  Text(
                    DateHelpers.formatCurrency(totalSpent),
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                ...members.map((m) {
                  final paid = data.paidAmounts[m.userId] ?? 0.0;
                  final share = data.shareAmounts[m.userId] ?? 0.0;
                  return DataCell(
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Paid: ₹${paid.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF10B981),
                          ),
                        ),
                        Text(
                          'Share: ₹${share.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArithmeticHisaabCard(
    BuildContext context,
    List<dynamic> members,
    GroupBalanceData data,
    String myUserId,
  ) {
    return _HisaabArithmeticCards(
      members: members.cast<Profile>(),
      data: data,
      myUserId: myUserId,
    );
  }

  Widget _buildFinalConclusionCard(
    BuildContext context,
    GroupBalanceData data,
    Group group,
  ) {
    return _HisaabFinalConclusion(data: data, group: group);
  }
}

/// Top-level reusable builder for the Hisaab Breakdown content.
/// Used by both [GroupBalancesDetailPage] (standalone route) and
/// [GroupDetailPage] (embedded in Balances & Settle tab).
Widget buildHisaabBreakdownContent({
  required BuildContext context,
  required Group group,
  required GroupBalanceData data,
  required dynamic currentUser,
  bool showHeroHeader = true,
}) {
  final myUserId = (currentUser?.id as String?) ?? '';
  final members = data.profiles.values.toList();
  final activeExpenses = data.unsettledExpenses;
  final totalSpent = activeExpenses.fold<double>(0.0, (sum, e) => sum + e.amount);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // ── Top Hero Card ──
      if (showHeroHeader) ...[
        _HisaabHeroHeader(group: group, totalSpent: totalSpent, memberCount: members.length, billCount: data.unsettledExpensesCount),
        const SizedBox(height: 20),
      ],

      // ── Section 1: Excel Spreadsheet Matrix ──
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.table_chart_rounded, size: 18, color: Color(0xFF10B981)),
              ),
              const SizedBox(width: 8),
              Text(
                'Expense Matrix (Spreadsheet)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${activeExpenses.length} Bills',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      Text(
        'Scroll horizontally to view each member\'s exact share and payment',
        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      const SizedBox(height: 12),

      _HisaabExcelMatrix(expenses: activeExpenses, members: members, data: data, totalSpent: totalSpent),
      const SizedBox(height: 24),

      // ── Section 2: Step-by-Step Hisaab Math ──
      Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.calculate_rounded, size: 18, color: Color(0xFF3B82F6)),
          ),
          const SizedBox(width: 8),
          Text(
            'Balance Calculation Breakdown',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      Text(
        'Step-by-step arithmetic for expenses, consumption share, and settlements',
        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      const SizedBox(height: 12),

      _HisaabArithmeticCards(members: members, data: data, myUserId: myUserId),
      const SizedBox(height: 24),

      // ── Section 3: Final Settlement Conclusion ──
      Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.check_circle_outline_rounded, size: 18, color: Color(0xFFF59E0B)),
          ),
          const SizedBox(width: 8),
          Text(
            'Final Settlement Conclusion',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      Text(
        'Optimized minimum payment transfers to clear all remaining balances:',
        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      const SizedBox(height: 12),

      _HisaabFinalConclusion(data: data, group: group),
    ],
  );
}

/// Wrapper widgets that delegate to the private methods of GroupBalancesDetailPage.
/// These extract the rendering logic into standalone stateless widgets.

class _HisaabHeroHeader extends StatelessWidget {
  final Group group;
  final double totalSpent;
  final int memberCount;
  final int billCount;
  const _HisaabHeroHeader({required this.group, required this.totalSpent, required this.memberCount, required this.billCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surface,
            AppColors.surfaceVariant.withValues(alpha: 0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primary,
                            const Color(0xFF41A5FF),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          group.name.isNotEmpty ? group.name[0].toUpperCase() : 'G',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.name,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$memberCount Members • Active Cycle',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Active Spend',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateHelpers.formatCurrency(totalSpent),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: billCount > 0
                      ? const Color(0xFFF59E0B).withValues(alpha: 0.12)
                      : const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: billCount > 0
                        ? const Color(0xFFF59E0B).withValues(alpha: 0.3)
                        : const Color(0xFF10B981).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      billCount > 0 ? Icons.receipt_long_rounded : Icons.check_circle_rounded,
                      size: 14,
                      color: billCount > 0 ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      billCount > 0 ? '$billCount Unsettled' : 'All Clear',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: billCount > 0 ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HisaabExcelMatrix extends StatelessWidget {
  final List<Expense> expenses;
  final List<dynamic> members;
  final GroupBalanceData data;
  final double totalSpent;
  const _HisaabExcelMatrix({required this.expenses, required this.members, required this.data, required this.totalSpent});

  @override
  Widget build(BuildContext context) {
    if (expenses.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          children: [
            const Icon(Icons.check_circle_outline_rounded, size: 48, color: Color(0xFF10B981)),
            const SizedBox(height: 12),
            const Text(
              'All Expenses Settled!',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'No active bills currently pending settlement.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: DataTable(
          columnSpacing: 22,
          horizontalMargin: 16,
          headingRowColor: WidgetStateProperty.all(
            AppColors.surfaceVariant.withValues(alpha: 0.8),
          ),
          dataRowMinHeight: 48,
          dataRowMaxHeight: 56,
          border: TableBorder(
            horizontalInside: BorderSide(color: AppColors.borderLight, width: 0.8),
            verticalInside: BorderSide(color: AppColors.borderLight.withValues(alpha: 0.5), width: 0.6),
          ),
          columns: [
            const DataColumn(
              label: Text(
                '#',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            const DataColumn(
              label: Text(
                'Date',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            const DataColumn(
              label: Text(
                'Expense Description',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            const DataColumn(
              label: Text(
                'Paid By (Amount)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            ...members.map(
              (m) => DataColumn(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 11,
                      backgroundColor: AppColors.primary,
                      child: Text(
                        m.fullName.isNotEmpty ? m.fullName[0].toUpperCase() : 'U',
                        style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      m.fullName.split(' ').first,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ],
          rows: [
            ...List.generate(expenses.length, (index) {
              final exp = expenses[index];
              final payer = data.profiles[exp.userId];
              final payerName = payer?.fullName.split(' ').first ?? 'User';
              final splits = data.splitsByExpense[exp.id] ?? [];
              final splitMap = {for (var s in splits) s.userId: s};
              final isEven = index % 2 == 0;

              return DataRow(
                color: WidgetStateProperty.all(
                  isEven ? AppColors.surface : AppColors.surfaceVariant.withValues(alpha: 0.25),
                ),
                cells: [
                  DataCell(
                    Text(
                      '${index + 1}',
                      style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                    ),
                  ),
                  DataCell(
                    Text(
                      DateHelpers.formatDayMonth(exp.expenseDate),
                      style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CategoryIconHelper.getIcon(exp.category),
                          size: 16,
                          color: AppColors.categoryColor(exp.category),
                        ),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 140),
                          child: Text(
                            exp.description,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$payerName: ₹${exp.amount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ),
                  ),
                  ...members.map((m) {
                    final split = splitMap[m.userId];
                    if (split == null || !split.isIncluded || split.amountOwed <= 0.01) {
                      return DataCell(
                        Center(
                          child: Text(
                            '—',
                            style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                          ),
                        ),
                      );
                    }
                    return DataCell(
                      Text(
                        '₹${split.amountOwed.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: m.userId == exp.userId
                              ? const Color(0xFF10B981)
                              : AppColors.textPrimary,
                        ),
                      ),
                    );
                  }),
                ],
              );
            }),

            // ── TOTALS FOOTER ROW ──
            DataRow(
              color: WidgetStateProperty.all(
                AppColors.primary.withValues(alpha: 0.08),
              ),
              cells: [
                const DataCell(Text('Σ', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15))),
                const DataCell(Text('TOTAL', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13))),
                DataCell(
                  Text(
                    '${expenses.length} Items',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                  ),
                ),
                DataCell(
                  Text(
                    DateHelpers.formatCurrency(totalSpent),
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                ...members.map((m) {
                  final paid = data.paidAmounts[m.userId] ?? 0.0;
                  final share = data.shareAmounts[m.userId] ?? 0.0;
                  return DataCell(
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Paid: ₹${paid.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF10B981),
                          ),
                        ),
                        Text(
                          'Share: ₹${share.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HisaabArithmeticCards extends StatelessWidget {
  final List<dynamic> members;
  final GroupBalanceData data;
  final String myUserId;
  const _HisaabArithmeticCards({required this.members, required this.data, required this.myUserId});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: members.map((m) {
        final isMe = m.userId == myUserId;
        final paid = data.paidAmounts[m.userId] ?? 0.0;
        final share = data.shareAmounts[m.userId] ?? 0.0;
        final expenseBalance = paid - share;
        final net = data.netBalances[m.userId] ?? 0.0;
        final isSettled = net.abs() < 0.05;
        final isGetsBack = net > 0.05;

        // Active settlements relevant to the current unsettled expenses cycle
        final unsettledExpIds = data.unsettledExpenses.map((e) => e.id).toSet();
        final activeSettlements = data.settlements.where((s) =>
            s.settledExpenseIds.any((id) => unsettledExpIds.contains(id))).toList();

        final paidSets = activeSettlements.where((s) => s.fromUserId == m.userId).toList();
        final recSets = activeSettlements.where((s) => s.toUserId == m.userId).toList();
        final double totalPaidSettled = paidSets.fold(0.0, (sum, s) => sum + s.amount);
        final double totalRecSettled = recSets.fold(0.0, (sum, s) => sum + s.amount);
        final bool hasSettlements = totalPaidSettled > 0.01 || totalRecSettled > 0.01;

        final badgeColor = isSettled
            ? const Color(0xFF10B981)
            : (isGetsBack ? const Color(0xFF10B981) : AppColors.error);
        final badgeText = isSettled
            ? 'Fully Settled (₹0)'
            : (isGetsBack
                ? '+ Gets back ${DateHelpers.formatCurrency(net)}'
                : '- Owes ${DateHelpers.formatCurrency(-net)}');

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isMe ? AppColors.primary.withValues(alpha: 0.4) : AppColors.borderLight,
              width: isMe ? 1.5 : 1.0,
            ),
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
              // Header: Name + Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.primary,
                        child: Text(
                          m.fullName.isNotEmpty ? m.fullName[0].toUpperCase() : 'U',
                          style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isMe ? '${m.fullName} (You)' : m.fullName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: badgeColor.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSettled) ...[
                          Icon(Icons.check_circle_rounded, size: 12, color: badgeColor),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          badgeText,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: badgeColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 16),

              // Equation: Total Paid - Share = Expense/Net Balance
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Paid', style: TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(
                            DateHelpers.formatCurrency(paid),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 5),
                    child: Text('—', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Consumed Share', style: TextStyle(fontSize: 11, color: AppColors.error, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(
                            DateHelpers.formatCurrency(share),
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.error),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 5),
                    child: Text('=', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (hasSettlements
                                ? (expenseBalance >= 0 ? const Color(0xFF10B981) : AppColors.error)
                                : badgeColor)
                            .withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hasSettlements ? 'Expense Balance' : 'Net Balance',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: hasSettlements
                                  ? (expenseBalance >= 0 ? const Color(0xFF10B981) : AppColors.error)
                                  : badgeColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            expenseBalance.abs() < 0.05
                                ? '₹0'
                                : (expenseBalance > 0
                                    ? '+${DateHelpers.formatCurrency(expenseBalance)}'
                                    : '-${DateHelpers.formatCurrency(-expenseBalance)}'),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: hasSettlements
                                  ? (expenseBalance >= 0 ? const Color(0xFF10B981) : AppColors.error)
                                  : badgeColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Compact Settlement Adjustment Bar (clean single-line, non-expanding)
              if (hasSettlements) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF10B981)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _getSettlementSummaryText(data, m.userId, paidSets, recSets, totalPaidSettled, totalRecSettled),
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF047857),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSettled ? const Color(0xFF10B981) : AppColors.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isSettled ? 'Net: ₹0 ✓' : 'Net: ${isGetsBack ? '+' : '-'}${DateHelpers.formatCurrency(net.abs())}',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  static String _getSettlementSummaryText(
    GroupBalanceData data,
    String userId,
    List<Settlement> paidSets,
    List<Settlement> recSets,
    double totalPaid,
    double totalRec,
  ) {
    if (paidSets.isNotEmpty && recSets.isEmpty) {
      if (paidSets.length == 1) {
        final toName = data.profiles[paidSets.first.toUserId]?.fullName ?? 'Member';
        final dateStr = DateHelpers.formatDayMonth(paidSets.first.createdAt);
        return 'Settled: Paid ${DateHelpers.formatCurrency(paidSets.first.amount)} to $toName on $dateStr';
      } else {
        return 'Settled: Paid ${DateHelpers.formatCurrency(totalPaid)} across ${paidSets.length} payments';
      }
    } else if (recSets.isNotEmpty && paidSets.isEmpty) {
      if (recSets.length == 1) {
        final fromName = data.profiles[recSets.first.fromUserId]?.fullName ?? 'Member';
        final dateStr = DateHelpers.formatDayMonth(recSets.first.createdAt);
        return 'Settled: Received ${DateHelpers.formatCurrency(recSets.first.amount)} from $fromName on $dateStr';
      } else {
        return 'Settled: Received ${DateHelpers.formatCurrency(totalRec)} across ${recSets.length} payments';
      }
    } else {
      return 'Settled: Paid ${DateHelpers.formatCurrency(totalPaid)}, Received ${DateHelpers.formatCurrency(totalRec)}';
    }
  }
}

class _HisaabFinalConclusion extends StatelessWidget {
  final GroupBalanceData data;
  final Group group;
  const _HisaabFinalConclusion({required this.data, required this.group});

  @override
  Widget build(BuildContext context) {
    final txs = data.transactions;

    if (txs.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 36),
            ),
            const SizedBox(height: 12),
            const Text(
              'All Members are Settled Up!',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Everyone has paid their exact share. No pending transactions.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final double totalSettlementVolume = txs.fold<double>(0.0, (sum, t) => sum + t.amount);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header summary badge bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant.withValues(alpha: 0.4),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
              border: Border(
                bottom: BorderSide(color: AppColors.borderLight),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.swap_horiz_rounded, size: 18, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      '${txs.length} ${txs.length == 1 ? 'Transfer' : 'Transfers'} Needed',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Text(
                    'Volume: ${DateHelpers.formatCurrency(totalSettlementVolume)}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Transfer list
          Padding(
            padding: const EdgeInsets.all(14),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: txs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, idx) {
                final tx = txs[idx];
                final fromProfile = data.profiles[tx.fromUserId];
                final toProfile = data.profiles[tx.toUserId];
                final fromName = fromProfile?.fullName.trim().isNotEmpty == true ? fromProfile!.fullName : 'Member';
                final toName = toProfile?.fullName.trim().isNotEmpty == true ? toProfile!.fullName : 'Member';

                final fromInitial = fromName.isNotEmpty ? fromName[0].toUpperCase() : 'P';
                final toInitial = toName.isNotEmpty ? toName[0].toUpperCase() : 'R';

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.borderLight.withValues(alpha: 0.7)),
                  ),
                  child: Row(
                    children: [
                      // Payer Avatar
                      CircleAvatar(
                        radius: 17,
                        backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.12),
                        child: Text(
                          fromInitial,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Payer details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              fromName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 1),
                            const Text(
                              'Payer',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFEF4444),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Direction Arrow & Amount Pill
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.borderLight),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.arrow_forward_rounded,
                                size: 13,
                                color: Color(0xFF64748B),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                DateHelpers.formatCurrency(tx.amount),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFEF4444),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Receiver details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              toName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                            ),
                            const SizedBox(height: 1),
                            const Text(
                              'Receiver',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF10B981),
                              ),
                              textAlign: TextAlign.end,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Receiver Avatar
                      CircleAvatar(
                        radius: 17,
                        backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.12),
                        child: Text(
                          toInitial,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

