import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/date_helpers.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../auth/data/auth_repository.dart';
import '../../settlement/data/settlement_repository.dart';
import '../data/expense_repository.dart';
import '../domain/expense_model.dart';
import '../domain/expense_item_model.dart';
import 'add_expense/add_expense_screen.dart';
import 'utils/category_icon_helper.dart';
import 'my_expenses_page.dart';

class PersonalExpensesPage extends ConsumerStatefulWidget {
  final DateTime month;

  const PersonalExpensesPage({super.key, required this.month});

  @override
  ConsumerState<PersonalExpensesPage> createState() => _PersonalExpensesPageState();
}

class _PersonalExpensesPageState extends ConsumerState<PersonalExpensesPage> {
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

  void _editExpense(Expense expense) {
    HapticHelper.lightTap();
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => AddExpenseScreen(group: null, existingExpense: expense),
      ),
    );
  }

  void _deleteExpense(Expense expense) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense?'),
        content: Text(
          'Are you sure you want to delete "${expense.description}" (${DateHelpers.formatCurrency(expense.amount)})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.textPrimary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      HapticHelper.heavyTap();
      final currentUser = ref.read(authStateProvider).valueOrNull;
      await ref.read(expenseRepositoryProvider).deleteExpense(
        expense.id,
        deleterUserId: currentUser?.id,
        deleterName: currentUser?.name,
      );
      ref.invalidate(monthlyExpensesProvider);
      ref.invalidate(userCashFlowProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('"${expense.description}" deleted successfully'),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFEF4444),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final month = ref.watch(analyticsMonthProvider);
    final expensesAsync = ref.watch(monthlyExpensesProvider(month));
    final currentUser = ref.watch(authStateProvider).valueOrNull;
    final myUserId = currentUser?.id;
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

            // Subtitle & Back Action Row (Directly below Month Bar)
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
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.25)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_rounded, size: 14, color: Color(0xFF10B981)),
                        SizedBox(width: 6),
                        Text(
                          'Personal Expenses',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // Content List
            Expanded(
              child: expensesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(
                  child: Text('Error loading expenses: $err', style: const TextStyle(color: Colors.red)),
                ),
                data: (allExpenses) {
                  final expenseItems = ref.watch(monthlyExpenseItemsProvider(month)).valueOrNull ?? [];
                  final userSplits = ref.watch(userSplitsProvider).valueOrNull ?? [];
                  final List<PersonalExpenseDisplayItem> personalItems = [];

                  // 1. Pure personal expenses
                  for (final e in allExpenses) {
                    final isPersonal = e.groupId == null || e.groupId!.isEmpty;
                    final isMine = myUserId != null && e.userId == myUserId;

                    if (isPersonal && isMine) {
                      if (_customDateRange != null) {
                        final within = e.expenseDate.isAfter(_customDateRange!.start.subtract(const Duration(seconds: 1))) &&
                            e.expenseDate.isBefore(_customDateRange!.end.add(const Duration(days: 1)));
                        if (!within) continue;
                      }
                      personalItems.add(
                        PersonalExpenseDisplayItem(
                          expense: e,
                          title: e.description,
                          amount: e.amount,
                          date: e.expenseDate,
                          category: e.category,
                          isItemwise: false,
                        ),
                      );
                    }
                  }

                  // 2. Personal items from item-wise group expenses
                  for (final e in allExpenses.where((e) => e.isGroup && e.splitType == 'itemwise')) {
                    if (_customDateRange != null) {
                      final within = e.expenseDate.isAfter(_customDateRange!.start.subtract(const Duration(seconds: 1))) &&
                          e.expenseDate.isBefore(_customDateRange!.end.add(const Duration(days: 1)));
                      if (!within) continue;
                    }
                    final items = expenseItems.where((i) => i.expenseId == e.id).toList();
                    for (final item in items) {
                      if (item.participants.length == 1 && item.participants.first == myUserId) {
                        personalItems.add(
                          PersonalExpenseDisplayItem(
                            expense: e,
                            item: item,
                            title: item.itemName.isNotEmpty ? item.itemName : e.description,
                            amount: item.itemAmount,
                            date: e.expenseDate,
                            category: e.category,
                            groupName: e.description,
                            isItemwise: true,
                          ),
                        );
                      }
                    }
                  }

                  // 3. Group expenses where this user has 100% share
                  for (final e in allExpenses.where((e) => e.isGroup && e.splitType != 'itemwise')) {
                    if (_customDateRange != null) {
                      final within = e.expenseDate.isAfter(_customDateRange!.start.subtract(const Duration(seconds: 1))) &&
                          e.expenseDate.isBefore(_customDateRange!.end.add(const Duration(days: 1)));
                      if (!within) continue;
                    }
                    final match = userSplits.where((s) => s.expenseId == e.id && s.userId == myUserId).toList();
                    if (match.isNotEmpty && match.first.amountOwed == e.amount && e.amount > 0) {
                      personalItems.add(
                        PersonalExpenseDisplayItem(
                          expense: e,
                          title: e.description,
                          amount: e.amount,
                          date: e.expenseDate,
                          category: e.category,
                          groupName: e.description,
                          isItemwise: false,
                        ),
                      );
                    }
                  }

                  personalItems.sort((a, b) => b.date.compareTo(a.date));

                  final totalPersonal = personalItems.fold<double>(
                    0.0,
                    (sum, e) => sum + e.amount,
                  );

                  return CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    slivers: [
                      // Total Spent Card
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF10B981),
                                  Color(0xFF059669),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.lock_outline_rounded, color: Colors.white, size: 16),
                                    SizedBox(width: 6),
                                    Text(
                                      'TOTAL PERSONAL SPENT',
                                      style: TextStyle(
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
                                  DateHelpers.formatCurrency(totalPersonal),
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${personalItems.length} ${personalItems.length == 1 ? 'item' : 'items'} recorded this month',
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Section Title
                      if (personalItems.isNotEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Text(
                              'Transactions & Items',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),

                      // Transactions List
                      if (personalItems.isEmpty)
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
                                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.person_outline_rounded,
                                      size: 48,
                                      color: Color(0xFF10B981),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No Personal Expenses',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'You haven\'t logged any private personal expenses or personal items for this period.',
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
                                final item = personalItems[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _buildPersonalExpenseCard(context, item),
                                );
                              },
                              childCount: personalItems.length,
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

  Widget _buildPersonalExpenseCard(BuildContext context, PersonalExpenseDisplayItem displayItem) {
    final expense = displayItem.expense;
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
            CategoryIconHelper.buildBadge(displayItem.category),
            const SizedBox(width: 14),

            // Title & Date
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayItem.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (displayItem.isItemwise) ...[
                    const SizedBox(height: 2),
                    Text(
                      'from "${expense.description}"',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        DateHelpers.formatDayMonth(displayItem.date),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (displayItem.isItemwise)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'PERSONAL ITEM',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF3B82F6),
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            displayItem.category.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Amount
            Text(
              DateHelpers.formatCurrency(displayItem.amount),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF10B981),
              ),
            ),

            // 3-Dot Quick Actions Menu (View, Edit & Delete)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, size: 20, color: AppColors.textSecondary),
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              onSelected: (val) {
                if (val == 'view') {
                  context.push('/expense-detail', extra: expense);
                } else if (val == 'edit') {
                  _editExpense(expense);
                } else if (val == 'delete') {
                  _deleteExpense(expense);
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'view',
                  child: Row(
                    children: [
                      Icon(Icons.visibility_outlined, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 10),
                      const Text(
                        'View Details',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                if (!displayItem.isItemwise) ...[
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
                        const SizedBox(width: 10),
                        const Text(
                          'Edit Expense',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                        SizedBox(width: 10),
                        Text(
                          'Delete Expense',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class PersonalExpenseDisplayItem {
  final Expense expense;
  final ExpenseItem? item;
  final String title;
  final double amount;
  final DateTime date;
  final String category;
  final String? groupName;
  final bool isItemwise;

  PersonalExpenseDisplayItem({
    required this.expense,
    this.item,
    required this.title,
    required this.amount,
    required this.date,
    required this.category,
    this.groupName,
    this.isItemwise = false,
  });
}
