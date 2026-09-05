import 'package:flutter/material.dart';
import '../../../core/utils/haptic_helper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/utils/date_helpers.dart';
import '../../../shared/services/categorize_service.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/utils/throttler.dart';
import '../domain/expense_model.dart';
import '../domain/expense_item_model.dart';
import '../data/expense_repository.dart';
import '../../calendar/presentation/widgets/calendar_expense_card.dart'; // For group/profile providers
import 'add_expense/add_expense_screen.dart';
import 'utils/category_icon_helper.dart';
import '../../auth/data/auth_repository.dart';
import '../../settlement/data/settlement_repository.dart';
import '../../settlement/presentation/settlement_page.dart';
import '../../groups/presentation/group_detail_page.dart';

class ExpenseDetailPage extends ConsumerStatefulWidget {
  final Expense expense;
  const ExpenseDetailPage({super.key, required this.expense});

  @override
  ConsumerState<ExpenseDetailPage> createState() => _ExpenseDetailPageState();
}

class _ExpenseDetailPageState extends ConsumerState<ExpenseDetailPage> {
  bool isDeleting = false;
  final _throttler = Throttler();

  @override
  void dispose() {
    _throttler.dispose();
    super.dispose();
  }

  void _deleteExpense() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense?'),
        content: const Text(
          'This will permanently delete this expense and all associated splits.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.textPrimary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              minimumSize: const Size(100, 48),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: AppColors.surface)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final currentUser = ref.read(authStateProvider).valueOrNull;
    setState(() => isDeleting = true);
    try {
      await ref.read(expenseRepositoryProvider).deleteExpense(
        widget.expense.id,
        deleterUserId: currentUser?.id,
        deleterName: currentUser?.name,
      );

      // Invalidate relevant providers
      ref.invalidate(monthlyExpensesProvider);
      ref.invalidate(userCashFlowProvider);
      if (widget.expense.groupId != null) {
        ref.invalidate(groupBalancesProvider(widget.expense.groupId!));
        ref.invalidate(groupAllExpensesProvider(widget.expense.groupId!));
      }
      ref.invalidate(userSplitsProvider);

      if (mounted) {
        HapticHelper.heavyTap();
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('"${widget.expense.description}" deleted successfully'),
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
            content: Text('Failed to delete: ${ErrorFormatter.format(e)}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final expense = widget.expense;
    final isGroup = expense.isGroup;
    final currentUser = ref.watch(authStateProvider).valueOrNull;
    final isOwner = currentUser != null && currentUser.id == expense.userId;

    // Fetch related details
    final profileAsync = ref.watch(profileByIdProvider(expense.userId));
    final groupAsync = isGroup && expense.groupId != null
        ? ref.watch(groupByIdProvider(expense.groupId!))
        : const AsyncValue.data(null);
    final splitsAsync = isGroup
        ? ref.watch(expenseSplitsProvider(expense.id))
        : const AsyncValue.data([]);
    final itemsAsync = (isGroup && expense.splitType == 'itemwise')
        ? ref.watch(expenseItemsProvider(expense.id))
        : const AsyncValue.data(<ExpenseItem>[]);

    final groupBalancesAsync = isGroup && expense.groupId != null
        ? ref.watch(groupBalancesProvider(expense.groupId!))
        : const AsyncValue.data(null);

    bool isLocked = expense.isSettled;
    if (!isLocked && isGroup) {
      final balancesData = groupBalancesAsync.valueOrNull;
      if (balancesData != null && balancesData.lastSettlement != null) {
        // If there's any settlement created AFTER this expense was added, this expense 
        // was factored into that settlement, so modifying it would corrupt the ledger.
        isLocked = expense.createdAt.isBefore(balancesData.lastSettlement!.createdAt) || expense.createdAt.isAtSameMomentAs(balancesData.lastSettlement!.createdAt);
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Expense Details',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          if (isOwner && (!isLocked || !isGroup)) ...[
            IconButton(
              icon: Icon(Icons.edit_outlined, color: AppColors.textPrimary),
              onPressed: () => _throttler.run(() async {
                final group = expense.isGroup && expense.groupId != null
                    ? await ref.read(groupByIdProvider(expense.groupId!).future)
                    : null;
                
                if (!mounted) return;
                if (context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddExpenseScreen(group: group, existingExpense: expense),
                    ),
                  );
                }
              }),
            ),
            if (isDeleting)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.error,
                    ),
                  ),
                ),
              )
            else
              IconButton(
                icon: Icon(Icons.delete_outline, color: AppColors.error),
                onPressed: _deleteExpense,
              ),
          ]
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Category Icon
            CategoryIconHelper.buildBadge(expense.category, size: 84, iconSize: 42),
            const SizedBox(height: AppSpacing.md),

            // Description & Amount
            Text(
              expense.description,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              DateHelpers.formatCurrency(expense.amount),
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            if (isLocked) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_rounded, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      'Locked (Settlement Recorded)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),

            // Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                children: [
                  _InfoRow(
                    icon: Icons.calendar_today,
                    label: 'Date',
                    value: DateHelpers.formatFullDate(expense.expenseDate),
                  ),
                  Divider(height: 24, color: AppColors.borderLight),
                  _InfoRow(
                    icon: Icons.category_outlined,
                    label: 'Category',
                    value: CategorizeService.displayName(expense.category),
                  ),
                  Divider(height: 24, color: AppColors.borderLight),
                  _InfoRow(
                    icon: Icons.person_outline,
                    label: 'Added By',
                    value: profileAsync.valueOrNull?.fullName ?? 'Loading...',
                  ),
                  Divider(height: 24, color: AppColors.borderLight),
                  _InfoRow(
                    icon: Icons.tag,
                    label: 'Type',
                    value: isGroup ? 'Group Expense' : 'Personal Expense',
                    valueColor: isGroup
                        ? const Color(0xFFF97316)
                        : const Color(0xFF3B82F6),
                  ),
                  if (isGroup && groupAsync.valueOrNull != null) ...[
                    Divider(height: 24, color: AppColors.borderLight),
                    _InfoRow(
                      icon: Icons.group_outlined,
                      label: 'Group',
                      value: groupAsync.valueOrNull!.name,
                    ),
                  ],
                ],
              ),
            ),

            if (isGroup) ...[
              if (expense.splitType == 'itemwise') ...[
                const SizedBox(height: AppSpacing.xl),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'ITEM DETAILS',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                itemsAsync.when(
                  loading: () => const CircularProgressIndicator(),
                  error: (e, _) => Text('Error: $e'),
                  data: (items) {
                    final currentUser = ref.watch(authStateProvider).valueOrNull;
                    if (items.isEmpty) return const SizedBox.shrink();
                    return Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        clipBehavior: Clip.antiAlias,
                        child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: items.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: AppColors.borderLight),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final isParticipating = currentUser != null && item.participants.contains(currentUser.id);
                          final share = isParticipating ? (item.itemAmount / item.participants.length) : 0.0;
                          return ListTile(
                            title: Text(
                              item.itemName.isNotEmpty ? item.itemName : 'Item ${index + 1}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            subtitle: Text(
                              'Total: ${DateHelpers.formatCurrency(item.itemAmount)} • Split among ${item.participants.length}',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            trailing: isParticipating
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Your Share',
                                        style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                      ),
                                      Text(
                                        DateHelpers.formatCurrency(share),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  )
                                : Text(
                                    'Not involved',
                                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                          );
                        },
                      ),
                    ),
                  );
                  },
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'SPLIT DETAILS',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              splitsAsync.when(
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => Text('Error: $e'),
                data: (splits) {
                  return Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      clipBehavior: Clip.antiAlias,
                      child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: splits.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: AppColors.borderLight),
                      itemBuilder: (context, index) {
                        final split = splits[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.surfaceVariant,
                            child: Icon(
                              Icons.person,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          title: ref
                              .watch(profileByIdProvider(split.userId))
                              .when(
                                data: (p) => Text(
                                  p?.fullName ?? 'Unknown',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                loading: () => const Text('...'),
                                error: (_, __) => const Text('Error'),
                              ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                DateHelpers.formatCurrency(split.amountOwed),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: split.isIncluded
                                      ? AppColors.textPrimary
                                      : AppColors.textSecondary,
                                  decoration: split.isIncluded
                                      ? null
                                      : TextDecoration.lineThrough,
                                ),
                              ),
                              if (split.isIncluded && split.amountOwed > 0) ...[
                                Builder(builder: (context) {
                                  bool isPayer = split.userId == expense.userId;
                                  bool userSettled = false;
                                  if (expense.isSettled) {
                                    userSettled = true;
                                  } else {
                                    final balancesData = groupBalancesAsync.valueOrNull;
                                    if (balancesData != null) {
                                      final isExpenseUnsettled = balancesData.unsettledExpenses.any((u) => u.id == expense.id);
                                      if (!isExpenseUnsettled && balancesData.lastSettlement != null &&
                                          (expense.createdAt.isBefore(balancesData.lastSettlement!.createdAt) ||
                                              expense.createdAt.isAtSameMomentAs(balancesData.lastSettlement!.createdAt))) {
                                        userSettled = true;
                                      }
                                    }
                                  }
                                  
                                  String statusText = isPayer ? 'Paid' : (userSettled ? 'Settled' : 'Pending');
                                  Color statusColor = isPayer || userSettled ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
                                  
                                  return Text(
                                    statusText,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: statusColor,
                                    ),
                                  );
                                }),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                );
                },
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
