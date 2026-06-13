import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/utils/date_helpers.dart';
import '../../../shared/services/categorize_service.dart';
import '../domain/expense_model.dart';
import '../data/expense_repository.dart';
import '../../calendar/presentation/widgets/calendar_expense_card.dart'; // For group/profile providers

class ExpenseDetailPage extends ConsumerStatefulWidget {
  final Expense expense;
  const ExpenseDetailPage({super.key, required this.expense});

  @override
  ConsumerState<ExpenseDetailPage> createState() => _ExpenseDetailPageState();
}

class _ExpenseDetailPageState extends ConsumerState<ExpenseDetailPage> {
  bool isDeleting = false;

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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: AppColors.surface)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => isDeleting = true);
    try {
      await ref
          .read(expenseRepositoryProvider)
          .deleteExpense(widget.expense.id);

      // Invalidate relevant providers
      ref.invalidate(monthlyExpensesProvider);

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expense deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
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

    // Fetch related details
    final profileAsync = ref.watch(profileByIdProvider(expense.userId));
    final groupAsync = isGroup && expense.groupId != null
        ? ref.watch(groupByIdProvider(expense.groupId!))
        : const AsyncValue.data(null);
    final splitsAsync = isGroup
        ? ref.watch(expenseSplitsProvider(expense.id))
        : const AsyncValue.data([]);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Expense Details',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.edit_outlined, color: AppColors.textPrimary),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Editing existing expenses will be supported in a future update.',
                  ),
                ),
              );
            },
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
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Category Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Center(
                child: Text(
                  CategorizeService.iconForCategory(expense.category),
                  style: const TextStyle(fontSize: 40),
                ),
              ),
            ),
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
                          trailing: Text(
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
                        );
                      },
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
