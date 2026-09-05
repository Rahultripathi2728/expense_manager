import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/date_helpers.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../settlement/data/settlement_repository.dart';
import '../../settlement/domain/settlement_model.dart';
import '../domain/expense_model.dart';
import 'my_expenses_page.dart';
import 'utils/category_icon_helper.dart';

class CashFlowLedgerPage extends ConsumerStatefulWidget {
  final DateTime month;

  const CashFlowLedgerPage({super.key, required this.month});

  @override
  ConsumerState<CashFlowLedgerPage> createState() => _CashFlowLedgerPageState();
}

class _CashFlowLedgerPageState extends ConsumerState<CashFlowLedgerPage> {
  // 'all', 'received', 'paid', 'expense'
  String _activeTab = 'all';
  DateTimeRange? _customDateRange;

  void _pickMonth(DateTime currentMonth) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: currentMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) {
      setState(() => _customDateRange = null);
      ref.read(analyticsMonthProvider.notifier).state = DateTime(picked.year, picked.month);
    }
  }

  void _pickCustomDateRange(DateTime currentMonth) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: _customDateRange ??
          DateTimeRange(
            start: DateTime(currentMonth.year, currentMonth.month, 1),
            end: DateTime(currentMonth.year, currentMonth.month + 1, 0),
          ),
    );
    if (picked != null) {
      setState(() {
        _customDateRange = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final month = ref.watch(analyticsMonthProvider);
    final cashFlowAsync = ref.watch(userCashFlowProvider(month));
    final hasActiveFilter = _customDateRange != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Month Bar (100% Identical Coordinates & Layout with MyExpensesPage)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  // Previous Month
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
                        setState(() => _customDateRange = null);
                        ref.read(analyticsMonthProvider.notifier).state =
                            DateHelpers.previousMonth(month);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Current Month / Date Range Display
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _pickMonth(month),
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
                                _customDateRange != null
                                    ? '${DateHelpers.formatDayMonth(_customDateRange!.start)} - ${DateHelpers.formatDayMonth(_customDateRange!.end)}'
                                    : DateHelpers.formatMonthYear(month),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (DateHelpers.isCurrentMonth(month) && _customDateRange == null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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

                  // Next Month
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
                        setState(() => _customDateRange = null);
                        ref.read(analyticsMonthProvider.notifier).state =
                            DateHelpers.nextMonth(month);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Filter / Calendar Button
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
                        if (hasActiveFilter) {
                          setState(() => _customDateRange = null);
                        } else {
                          _pickCustomDateRange(month);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Subtitle & Back Action Row (Clean Page Title)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  InkWell(
                    onTap: () {
                      HapticHelper.lightTap();
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/expenses');
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_back_rounded, size: 16, color: AppColors.textPrimary),
                          const SizedBox(width: 4),
                          Text(
                            'Back',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.account_balance_wallet_rounded, size: 18, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        'Cash Flow & Ledger',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Main Content
            Expanded(
              child: cashFlowAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(
                  child: Text('Error loading cash flow: $err', style: const TextStyle(color: Colors.red)),
                ),
                data: (data) {
                  // Filter activities by date range if active
                  var activities = data.activities;
                  if (_customDateRange != null) {
                    activities = activities.where((a) {
                      return a.date.isAfter(_customDateRange!.start.subtract(const Duration(seconds: 1))) &&
                          a.date.isBefore(_customDateRange!.end.add(const Duration(days: 1)));
                    }).toList();
                  }

                  // Filter activities by active tab
                  final filteredActivities = activities.where((a) {
                    if (_activeTab == 'all') return true;
                    if (_activeTab == 'received') return a.type == CashFlowType.settlementReceived;
                    if (_activeTab == 'paid') return a.type == CashFlowType.settlementPaid;
                    if (_activeTab == 'expense') return a.type == CashFlowType.expense;
                    return true;
                  }).toList();

                  final countReceived = activities.where((a) => a.type == CashFlowType.settlementReceived).length;
                  final countPaid = activities.where((a) => a.type == CashFlowType.settlementPaid).length;
                  final countExpenses = activities.where((a) => a.type == CashFlowType.expense).length;

                  return CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    slivers: [
                      // 4-Card Hero Summary Grid (Clickable to switch tabs!)
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            children: [
                              // Row 1: Spent & Received
                              Row(
                                children: [
                                  // Spent Card -> Click to show Expenses
                                  Expanded(
                                    child: _buildMetricCard(
                                      title: 'TOTAL SPENT',
                                      amount: DateHelpers.formatCurrency(data.totalSpent),
                                      subtitle: 'Personal & Group share',
                                      icon: Icons.shopping_bag_outlined,
                                      accentColor: AppColors.primary,
                                      isPositive: null,
                                      isSelected: _activeTab == 'expense',
                                      onTap: () {
                                        HapticHelper.selectionClick();
                                        setState(() {
                                          _activeTab = _activeTab == 'expense' ? 'all' : 'expense';
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),

                                  // Received Card -> Click to show Received Settlements
                                  Expanded(
                                    child: _buildMetricCard(
                                      title: 'RECEIVED (+)',
                                      amount: '+${DateHelpers.formatCurrency(data.totalReceived)}',
                                      subtitle: '$countReceived settlements in',
                                      icon: Icons.arrow_downward_rounded,
                                      accentColor: const Color(0xFF10B981),
                                      isPositive: true,
                                      isSelected: _activeTab == 'received',
                                      onTap: () {
                                        HapticHelper.selectionClick();
                                        setState(() {
                                          _activeTab = _activeTab == 'received' ? 'all' : 'received';
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Row 2: Paid Out & Net Cashflow
                              Row(
                                children: [
                                  // Paid Out Card -> Click to show Paid Settlements
                                  Expanded(
                                    child: _buildMetricCard(
                                      title: 'PAID OUT (-)',
                                      amount: '-${DateHelpers.formatCurrency(data.totalPaidOut)}',
                                      subtitle: '$countPaid settlements out',
                                      icon: Icons.arrow_upward_rounded,
                                      accentColor: const Color(0xFFEF4444),
                                      isPositive: false,
                                      isSelected: _activeTab == 'paid',
                                      onTap: () {
                                        HapticHelper.selectionClick();
                                        setState(() {
                                          _activeTab = _activeTab == 'paid' ? 'all' : 'paid';
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),

                                  // Net Position Card -> Click to show All Activity
                                  Expanded(
                                    child: _buildMetricCard(
                                      title: 'NET CASH FLOW',
                                      amount: (data.netCashFlow >= 0 ? '+' : '') +
                                          DateHelpers.formatCurrency(data.netCashFlow),
                                      subtitle: data.netCashFlow >= 0 ? 'Surplus / Balanced' : 'Net Outflow',
                                      icon: Icons.swap_vert_rounded,
                                      accentColor: data.netCashFlow >= 0
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFFEF4444),
                                      isPositive: data.netCashFlow >= 0,
                                      isSelected: _activeTab == 'all',
                                      onTap: () {
                                        HapticHelper.selectionClick();
                                        setState(() => _activeTab = 'all');
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Segmented Activity Switcher
                      SliverToBoxAdapter(
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              children: [
                                _buildFilterTab('all', 'All Activity (${activities.length})'),
                                const SizedBox(width: 8),
                                _buildFilterTab('received', '🟢 Received ($countReceived)'),
                                const SizedBox(width: 8),
                                _buildFilterTab('paid', '🔴 Paid Out ($countPaid)'),
                                const SizedBox(width: 8),
                                _buildFilterTab('expense', '🧾 Expenses ($countExpenses)'),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Section Title
                      if (filteredActivities.isNotEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                            child: Text(
                              _activeTab == 'all'
                                  ? 'Activity Ledger'
                                  : _activeTab == 'received'
                                      ? 'Settlements Received (Money In)'
                                      : _activeTab == 'paid'
                                          ? 'Settlements Paid Out (Money Out)'
                                          : 'Expenses Logged',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),

                      // Activities List Feed
                      if (filteredActivities.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.receipt_long_outlined,
                                      size: 48,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No Records in this Section',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No transactions found for the selected tab and month.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final item = filteredActivities[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _buildActivityCard(context, item),
                                );
                              },
                              childCount: filteredActivities.length,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String amount,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required bool? isPositive,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? accentColor : AppColors.borderLight,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? accentColor.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.02),
              blurRadius: isSelected ? 10 : 6,
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
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? accentColor : AppColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: isSelected ? 0.2 : 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: accentColor, size: 14),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              amount,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: isPositive == null
                    ? AppColors.textPrimary
                    : isPositive
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? accentColor : AppColors.textTertiary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle_rounded, size: 12, color: accentColor),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTab(String key, String label) {
    final isSelected = _activeTab == key;

    return GestureDetector(
      onTap: () {
        HapticHelper.selectionClick();
        setState(() => _activeTab = key);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.borderLight,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
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

  Widget _buildActivityCard(BuildContext context, CashFlowActivityItem item) {
    final isReceived = item.type == CashFlowType.settlementReceived;
    final isPaid = item.type == CashFlowType.settlementPaid;
    final isExpense = item.type == CashFlowType.expense;

    final Color badgeColor = isReceived
        ? const Color(0xFF10B981)
        : isPaid
            ? const Color(0xFFEF4444)
            : AppColors.primary;

    return InkWell(
      onTap: () {
        if (isExpense && item.originalObject is Expense) {
          context.push('/expense-detail', extra: item.originalObject as Expense);
        } else if ((isReceived || isPaid) && item.originalObject is Settlement) {
          final s = item.originalObject as Settlement;
          context.push(
            '/settlement-history-detail',
            extra: {
              'settlement': s,
              'fromName': isPaid ? 'You' : item.title.replaceFirst('Received from ', ''),
              'toName': isReceived ? 'You' : item.title.replaceFirst('Paid to ', ''),
            },
          );
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
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
        child: Row(
          children: [
            // Leading Icon Badge
            if (isExpense)
              CategoryIconHelper.buildBadge(item.category ?? 'other')
            else
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.25), width: 1.2),
                ),
                child: Center(
                  child: Icon(
                    isReceived ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                    color: badgeColor,
                    size: 22,
                  ),
                ),
              ),
            const SizedBox(width: 14),

            // Title, Subtitle, Group Badge
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 2,
                    children: [
                      if (item.groupName != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: item.groupName == 'Personal'
                                ? const Color(0xFF10B981).withValues(alpha: 0.1)
                                : AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.groupName!,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: item.groupName == 'Personal'
                                  ? const Color(0xFF10B981)
                                  : AppColors.primary,
                            ),
                          ),
                        ),
                      Text(
                        DateHelpers.formatDayMonth(item.date),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Amount Column
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  (isReceived ? '+' : '-') + DateHelpers.formatCurrency(item.amount),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: isReceived ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isReceived
                      ? 'INFLOW 🟢'
                      : isPaid
                          ? 'SETTLED 🔴'
                          : 'EXPENSE 🧾',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isReceived
                        ? const Color(0xFF10B981)
                        : isPaid
                            ? const Color(0xFFEF4444)
                            : AppColors.textTertiary,
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
