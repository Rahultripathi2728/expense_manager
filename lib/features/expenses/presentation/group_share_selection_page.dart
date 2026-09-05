import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/date_helpers.dart';
import '../../auth/data/auth_repository.dart';
import '../../groups/data/group_repository.dart';
import '../../groups/domain/group_model.dart';
import '../data/expense_repository.dart';
import '../domain/expense_model.dart';
import 'utils/category_icon_helper.dart';
import 'my_expenses_page.dart';

class GroupShareSelectionPage extends ConsumerStatefulWidget {
  final DateTime month;

  const GroupShareSelectionPage({super.key, required this.month});

  @override
  ConsumerState<GroupShareSelectionPage> createState() => _GroupShareSelectionPageState();
}

class _GroupShareSelectionPageState extends ConsumerState<GroupShareSelectionPage> {
  String _selectedGroupId = 'all';
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
    final expensesAsync = ref.watch(monthlyExpensesProvider(month));
    final userSplitsAsync = ref.watch(userSplitsProvider);
    final groupsAsync = ref.watch(userGroupsProvider);
    final currentUser = ref.watch(authStateProvider).valueOrNull;
    final myUserId = currentUser?.id;
    final hasActiveFilter = _customDateRange != null;

    final groups = groupsAsync.valueOrNull ?? [];
    final groupMap = {for (var g in groups) g.id: g};

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

            // Subtitle & Back Action Row (Directly below Month Bar)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => context.pop(),
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
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.groups_rounded, size: 14, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          'My Share (Group Expenses)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // Horizontal Group Filter Chips
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // All Groups Chip
                    _buildGroupChip(
                      groupId: 'all',
                      label: 'All Groups',
                      isSelected: _selectedGroupId == 'all',
                    ),
                    const SizedBox(width: 8),

                    // Individual Group Chips
                    ...groups.map((g) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _buildGroupChip(
                          groupId: g.id,
                          label: g.name,
                          isSelected: _selectedGroupId == g.id,
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Content List
            Expanded(
              child: expensesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(
                  child: Text('Error loading expenses: $err', style: const TextStyle(color: Colors.red)),
                ),
                data: (allExpenses) {
                  return userSplitsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, _) => Center(
                      child: Text('Error loading splits: $err', style: const TextStyle(color: Colors.red)),
                    ),
                    data: (userSplits) {
                      final splitMap = {for (var s in userSplits) s.expenseId: s.amountOwed};

                      // Filter group expenses
                      final groupExpenses = allExpenses.where((e) {
                        final isGroup = e.groupId != null && e.groupId!.isNotEmpty;
                        if (!isGroup) return false;

                        // Match group filter
                        if (_selectedGroupId != 'all' && e.groupId != _selectedGroupId) {
                          return false;
                        }

                        // Match user participation (either payer or split participant)
                        final isPayer = myUserId != null && e.userId == myUserId;
                        final hasSplit = splitMap.containsKey(e.id);
                        if (!isPayer && !hasSplit) return false;

                        if (_customDateRange != null) {
                          return e.expenseDate.isAfter(_customDateRange!.start.subtract(const Duration(seconds: 1))) &&
                              e.expenseDate.isBefore(_customDateRange!.end.add(const Duration(days: 1)));
                        }
                        return true;
                      }).toList();

                      // Calculate user's total group share
                      double totalMyShare = 0.0;
                      for (final e in groupExpenses) {
                        final mySplitAmount = splitMap[e.id];
                        if (mySplitAmount != null) {
                          totalMyShare += mySplitAmount;
                        } else if (e.userId == myUserId) {
                          totalMyShare += e.amount;
                        }
                      }

                      return CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        slivers: [
                          // Total Share Card
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      AppColors.primary,
                                      const Color(0xFF60A5FA),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(alpha: 0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.people_alt_rounded, color: Colors.white, size: 16),
                                        const SizedBox(width: 6),
                                        Text(
                                          _selectedGroupId == 'all'
                                              ? 'MY SHARE ACROSS ALL GROUPS'
                                              : 'MY SHARE IN ${groupMap[_selectedGroupId]?.name.toUpperCase() ?? 'GROUP'}',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      DateHelpers.formatCurrency(totalMyShare),
                                      style: const TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${groupExpenses.length} ${groupExpenses.length == 1 ? 'group expense' : 'group expenses'} included',
                                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Section Title
                          if (groupExpenses.isNotEmpty)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                                child: Text(
                                  'Group Transactions',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ),

                          // Transactions List
                          if (groupExpenses.isEmpty)
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
                                          Icons.groups_outlined,
                                          size: 48,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No Group Expenses Found',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'No group expenses found for the selected month or group filter.',
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
                                    final expense = groupExpenses[index];
                                    final group = groupMap[expense.groupId];
                                    final myShare = splitMap[expense.id] ?? (expense.userId == myUserId ? expense.amount : 0.0);

                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: _buildGroupExpenseCard(context, expense, group, myShare),
                                    );
                                  },
                                  childCount: groupExpenses.length,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupChip({
    required String groupId,
    required String label,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() => _selectedGroupId = groupId);
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (groupId == 'all')
              Icon(
                Icons.all_inclusive_rounded,
                size: 14,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              )
            else
              Container(
                width: 16,
                height: 16,
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white24 : AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    label.isNotEmpty ? label[0].toUpperCase() : 'G',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : AppColors.primary,
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupExpenseCard(
    BuildContext context,
    Expense expense,
    Group? group,
    double myShare,
  ) {
    return InkWell(
      onTap: () => context.push('/expense-detail', extra: expense),
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
            // Category Icon
            CategoryIconHelper.buildBadge(expense.category),
            const SizedBox(width: 14),

            // Title, Group & Date
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.description,
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
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          group?.name ?? 'Group',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      Text(
                        DateHelpers.formatDayMonth(expense.expenseDate),
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

            // My Share & Total Bill
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  DateHelpers.formatCurrency(myShare),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Total ${DateHelpers.formatCurrency(expense.amount)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
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
