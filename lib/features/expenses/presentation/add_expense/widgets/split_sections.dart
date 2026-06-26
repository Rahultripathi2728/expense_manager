import 'package:flutter/material.dart';
import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../profile/domain/profile_model.dart';
import '../providers/add_expense_provider.dart';

class EquallySplitWidget extends StatelessWidget {
  final List<Profile> profiles;
  final SingleBillState activeBill;
  final AddExpenseNotifier notifier;

  const EquallySplitWidget({
    super.key,
    required this.profiles,
    required this.activeBill,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context) {
    final share = activeBill.selectedMemberIds.isNotEmpty
        ? activeBill.amount / activeBill.selectedMemberIds.length
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Split among (Tap to unselect)',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            TextButton(
              onPressed: notifier.selectAllMembers,
              child: Text(
                'Select All',
                style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: profiles.map((prof) {
            final isSelected = activeBill.selectedMemberIds.contains(prof.userId);
            return GestureDetector(
              onTap: () => notifier.toggleMember(prof.userId),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.textPrimary.withValues(alpha: 0.04)
                      : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? AppColors.textPrimary : AppColors.borderLight,
                    width: 1.2,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      prof.fullName.split(' ').first,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${isSelected ? share.toStringAsFixed(0) : '0'}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? AppColors.textPrimary
                            : AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class UnequalAmountTextField extends StatefulWidget {
  final String userId;
  final double initialValue;
  final ValueChanged<double> onChanged;

  const UnequalAmountTextField({
    super.key,
    required this.userId,
    required this.initialValue,
    required this.onChanged,
  });

  @override
  State<UnequalAmountTextField> createState() => _UnequalAmountTextFieldState();
}

class _UnequalAmountTextFieldState extends State<UnequalAmountTextField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialValue > 0.0 ? widget.initialValue.toStringAsFixed(2) : '',
    );
  }

  @override
  void didUpdateWidget(covariant UnequalAmountTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only update controller text if the initialValue changes from outside
    // and is different from what is currently typed (like when clicking 'Split All Equally')
    final currentTextVal = double.tryParse(_controller.text) ?? 0.0;
    if ((widget.initialValue - currentTextVal).abs() > 0.01) {
      _controller.text = widget.initialValue > 0.0 ? widget.initialValue.toStringAsFixed(2) : '';
      _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
      ),
      textAlign: TextAlign.right,
      decoration: const InputDecoration(
        prefixText: '₹',
        contentPadding: EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 8,
        ),
      ),
      controller: _controller,
      onChanged: (val) {
        final amt = double.tryParse(val) ?? 0.0;
        widget.onChanged(amt);
      },
    );
  }
}

class UnequallySplitWidget extends StatelessWidget {
  final List<Profile> profiles;
  final SingleBillState activeBill;
  final AddExpenseNotifier notifier;

  const UnequallySplitWidget({
    super.key,
    required this.profiles,
    required this.activeBill,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context) {
    double totalUnequal = 0.0;
    for (final amt in activeBill.unequalAmounts.values) {
      totalUnequal += amt;
    }

    final diff = activeBill.amount - totalUnequal;
    final isMatching = diff.abs() < 0.01;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isMatching
                  ? 'All splits match total'
                  : diff > 0
                  ? 'Remaining: ₹${diff.toStringAsFixed(2)}'
                  : 'Overallocated: ₹${(-diff).toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isMatching ? const Color(0xFF22C55E) : AppColors.error,
              ),
            ),
            OutlinedButton(
              onPressed: notifier.splitUnequallyEqually,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(110, 30),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                side: BorderSide(color: AppColors.border),
              ),
              child: Text(
                'Split All Equally',
                style: TextStyle(fontSize: 11, color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: profiles.length,
          itemBuilder: (context, index) {
            final prof = profiles[index];
            final currentVal = activeBill.unequalAmounts[prof.userId] ?? 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFFF3F3F3),
                    child: Text(
                      prof.fullName.substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      prof.fullName,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    height: 38,
                    child: UnequalAmountTextField(
                      key: ValueKey('unequal_field_${prof.userId}'),
                      userId: prof.userId,
                      initialValue: currentVal,
                      onChanged: (amt) {
                        notifier.updateUnequalAmount(prof.userId, amt);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class ItemwiseSplitWidget extends StatelessWidget {
  final List<Profile> profiles;
  final SingleBillState activeBill;
  final AddExpenseNotifier notifier;

  const ItemwiseSplitWidget({
    super.key,
    required this.profiles,
    required this.activeBill,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Items list',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ...activeBill.items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final itemTotal = item.price * item.qty;

          return Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: const Color(0xFFF9F9F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Item description...',
                          labelText: 'Description',
                        ),
                        onChanged: (val) =>
                            notifier.updateItemDescription(index, val),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: AppColors.error),
                      onPressed: () => notifier.removeItem(index),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Row(
                      children: [
                        Text(
                          'Qty: ',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.remove_circle_outline,
                            size: 18,
                          ),
                          onPressed: () =>
                              notifier.updateItemQty(index, item.qty - 1),
                        ),
                        Text(
                          '${item.qty}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, size: 18),
                          onPressed: () =>
                              notifier.updateItemQty(index, item.qty + 1),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      'Total: ₹${itemTotal.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Price per item',
                    prefixText: '₹',
                  ),
                  onChanged: (val) {
                    final price = double.tryParse(val) ?? 0.0;
                    notifier.updateItemPrice(index, price);
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                Text(
                  'Split Among (Tap names)',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    GestureDetector(
                      onTap: () {
                        for (final p in profiles) {
                          if (!item.participantIds.contains(p.userId)) {
                            notifier.toggleItemParticipant(index, p.userId);
                          }
                        }
                      },
                      child: Chip(
                        label: const Text(
                          'Equally',
                          style: TextStyle(fontSize: 10),
                        ),
                        backgroundColor:
                            item.participantIds.length == profiles.length
                            ? AppColors.textPrimary.withValues(alpha: 0.05)
                            : Colors.transparent,
                        side: BorderSide(color: AppColors.borderLight),
                      ),
                    ),
                    ...profiles.map((p) {
                      final isIncluded = item.participantIds.contains(p.userId);
                      return GestureDetector(
                        onTap: () =>
                            notifier.toggleItemParticipant(index, p.userId),
                        child: Chip(
                          label: Text(
                            p.fullName.split(' ').first,
                            style: const TextStyle(fontSize: 10),
                          ),
                          backgroundColor: isIncluded
                              ? AppColors.textPrimary.withValues(alpha: 0.05)
                              : Colors.transparent,
                          side: BorderSide(
                            color: isIncluded
                                ? AppColors.textPrimary
                                : AppColors.borderLight,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: notifier.addItem,
          icon: Icon(Icons.add, color: AppColors.textPrimary, size: 16),
          label: Text(
            'Add more item',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }
}
