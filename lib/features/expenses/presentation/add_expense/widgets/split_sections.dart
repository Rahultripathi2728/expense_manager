import 'package:flutter/material.dart';
import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../profile/domain/profile_model.dart';
import '../providers/add_expense_provider.dart';
import 'unequal_split_sheet.dart';
import '../../../../../core/utils/date_helpers.dart';
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
}class UnequallySplitWidget extends StatelessWidget {
  final List<Profile> profiles;
  final SingleBillState activeBill;
  final AddExpenseNotifier notifier;

  const UnequallySplitWidget({
    super.key,
    required this.profiles,
    required this.activeBill,
    required this.notifier,
  });

  void _openSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: UnequalSplitSheet(
          profiles: profiles,
          totalAmount: activeBill.amount,
          initialAmounts: activeBill.unequalAmounts,
          onApply: (newAmounts) {
            notifier.updateUnequalAmounts(newAmounts);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double totalUnequal = 0.0;
    for (final amt in activeBill.unequalAmounts.values) {
      totalUnequal += amt;
    }

    final diff = activeBill.amount - totalUnequal;
    final isMatching = diff.abs() < 0.01;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMatching ? const Color(0xFF22C55E) : AppColors.error,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Unequal Split',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isMatching
                        ? 'Total amount matched'
                        : diff > 0
                        ? 'Remaining: ${DateHelpers.formatCurrency(diff)}'
                        : 'Overallocated: ${DateHelpers.formatCurrency(-diff)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isMatching ? const Color(0xFF22C55E) : AppColors.error,
                    ),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: () => _openSheet(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  minimumSize: const Size(80, 36),
                ),
                child: const Text('Edit Split', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
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
    double totalItemsAmount = 0.0;
    for (final it in activeBill.items) {
      totalItemsAmount += (it.price * it.qty);
    }

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
            Text(
              'Total: ₹${totalItemsAmount.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        // Each item as a StatefulWidget with its own controllers
        ...List.generate(activeBill.items.length, (index) {
          final item = activeBill.items[index];
          return _SingleItemCard(
            key: ValueKey('item_card_$index'),
            index: index,
            item: item,
            profiles: profiles,
            totalItemsCount: activeBill.items.length,
            onDescriptionChanged: (val) => notifier.updateItemDescription(index, val),
            onPriceChanged: (val) => notifier.updateItemPrice(index, val),
            onQtyChanged: (qty) => notifier.updateItemQty(index, qty),
            onToggleParticipant: (userId) => notifier.toggleItemParticipant(index, userId),
            onSelectAll: () {
              for (final p in profiles) {
                if (!item.participantIds.contains(p.userId)) {
                  notifier.toggleItemParticipant(index, p.userId);
                }
              }
            },
            onRemove: () => notifier.removeItem(index),
          );
        }),

        const SizedBox(height: AppSpacing.sm),
        InkWell(
          onTap: notifier.addItem,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, color: AppColors.textPrimary, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Add more item',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SingleItemCard extends StatefulWidget {
  final int index;
  final ItemSplitState item;
  final List<Profile> profiles;
  final int totalItemsCount;
  final ValueChanged<String> onDescriptionChanged;
  final ValueChanged<double> onPriceChanged;
  final ValueChanged<int> onQtyChanged;
  final ValueChanged<String> onToggleParticipant;
  final VoidCallback onSelectAll;
  final VoidCallback onRemove;

  const _SingleItemCard({
    super.key,
    required this.index,
    required this.item,
    required this.profiles,
    required this.totalItemsCount,
    required this.onDescriptionChanged,
    required this.onPriceChanged,
    required this.onQtyChanged,
    required this.onToggleParticipant,
    required this.onSelectAll,
    required this.onRemove,
  });

  @override
  State<_SingleItemCard> createState() => _SingleItemCardState();
}

class _SingleItemCardState extends State<_SingleItemCard> {
  late TextEditingController _descCtrl;
  late TextEditingController _priceCtrl;

  @override
  void initState() {
    super.initState();
    _descCtrl = TextEditingController(text: widget.item.description);
    _priceCtrl = TextEditingController(
      text: widget.item.price > 0 ? widget.item.price.toStringAsFixed(2) : '',
    );
  }

  @override
  void didUpdateWidget(covariant _SingleItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only sync if value changed externally (not from typing)
    if (oldWidget.item.description != widget.item.description &&
        _descCtrl.text != widget.item.description) {
      _descCtrl.text = widget.item.description;
    }
    final currentPrice = double.tryParse(_priceCtrl.text) ?? 0.0;
    if ((currentPrice - widget.item.price).abs() > 0.01) {
      _priceCtrl.text = widget.item.price > 0 ? widget.item.price.toStringAsFixed(2) : '';
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemTotal = widget.item.price * widget.item.qty;

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
                  controller: _descCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Item description...',
                    labelText: 'Description',
                  ),
                  onChanged: widget.onDescriptionChanged,
                ),
              ),
              if (widget.totalItemsCount > 1)
                IconButton(
                  icon: Icon(Icons.delete_outline, color: AppColors.error),
                  onPressed: widget.onRemove,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Row(
                children: [
                  Text('Qty: ', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 18),
                    onPressed: () => widget.onQtyChanged(widget.item.qty - 1),
                  ),
                  Text('${widget.item.qty}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    onPressed: () => widget.onQtyChanged(widget.item.qty + 1),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                'Total: ₹${itemTotal.toStringAsFixed(2)}',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _priceCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Price per item',
              prefixText: '₹',
            ),
            onChanged: (val) {
              final price = double.tryParse(val) ?? 0.0;
              widget.onPriceChanged(price);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Split Among (Tap names)',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              GestureDetector(
                onTap: widget.onSelectAll,
                child: Chip(
                  label: const Text('Equally', style: TextStyle(fontSize: 10)),
                  backgroundColor: widget.item.participantIds.length == widget.profiles.length
                      ? AppColors.textPrimary.withValues(alpha: 0.05)
                      : Colors.transparent,
                  side: BorderSide(color: AppColors.borderLight),
                ),
              ),
              ...widget.profiles.map((p) {
                final isIncluded = widget.item.participantIds.contains(p.userId);
                return GestureDetector(
                  onTap: () => widget.onToggleParticipant(p.userId),
                  child: Chip(
                    label: Text(p.fullName.split(' ').first, style: const TextStyle(fontSize: 10)),
                    backgroundColor: isIncluded
                        ? AppColors.textPrimary.withValues(alpha: 0.05)
                        : Colors.transparent,
                    side: BorderSide(
                      color: isIncluded ? AppColors.textPrimary : AppColors.borderLight,
                    ),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }
}

