import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/utils/date_helpers.dart';
import '../../../shared/services/categorize_service.dart';
import '../../auth/data/auth_repository.dart';
import '../../groups/data/group_repository.dart';
import '../../groups/domain/group_member_model.dart';
import '../../groups/domain/group_model.dart';
import '../data/expense_repository.dart';

class GroupExpenseSheet extends ConsumerStatefulWidget {
  final Group group;

  const GroupExpenseSheet({super.key, required this.group});

  @override
  ConsumerState<GroupExpenseSheet> createState() => _GroupExpenseSheetState();
}

class _GroupExpenseSheetState extends ConsumerState<GroupExpenseSheet> {
  final _descCtrl = TextEditingController();
  final _amtCtrl = TextEditingController();
  String _selectedCategory = 'other';
  String _splitType = 'Equally'; // 'Equally', 'Unequally', 'Item wise'
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  List<GroupMember> _members = [];

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    final members = await ref
        .read(groupRepositoryProvider)
        .getGroupMembers(widget.group.id);
    setState(() {
      _members = members;
      // Initialize equal split logic
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, scrollController) => Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusXl),
          ),
        ),
        child: ListView(
          controller: scrollController,
          children: [
            // Top Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(
                      'Add Expense',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.home,
                        size: 16,
                        color: AppColors.primary,
                      ), // Placeholder for group icon
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        widget.group.name,
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            // Top section: Add Friends, You, Add bill
            Row(
              children: [
                Column(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.textPrimary,
                      child: Icon(Icons.add, color: AppColors.background),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    const Text('Add Friends'),
                  ],
                ),
                const SizedBox(width: AppSpacing.lg),
                Column(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor:
                          Colors.blue.shade100, // Placeholder avatar color
                      child: const Icon(Icons.person, color: Colors.blue),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    const Text('You'),
                  ],
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.add),
                  label: const Text('Add bill'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),

            // Input Fields
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Description',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      TextField(
                        controller: _descCtrl,
                        decoration: InputDecoration(
                          hintText: 'Add a description',
                          border: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                        ),
                        onChanged: (val) {
                          if (val.length > 3) {
                            setState(() {
                              _selectedCategory = CategorizeService.categorize(
                                val,
                              );
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xl),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Category',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedCategory,
                        items: CategorizeService.allCategories.map((c) {
                          return DropdownMenuItem(
                            value: c,
                            child: Row(
                              children: [
                                Text(CategorizeService.iconForCategory(c)),
                                const SizedBox(width: AppSpacing.sm),
                                Text(CategorizeService.displayName(c)),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedCategory = val);
                          }
                        },
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Price',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      TextField(
                        controller: _amtCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: '₹ Enter price',
                          border: InputBorder.none,
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xl),
                // Removed 'Paid By' field
                Expanded(child: Container()),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),

            // Split Options
            Text(
              'Split',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
              ),
              child: Row(
                children: ['Equally', 'Unequally', 'Item wise'].map((type) {
                  final isSelected = _splitType == type;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _splitType = type),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.md,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusXl,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            type,
                            style: TextStyle(
                              color: isSelected
                                  ? AppColors.surface
                                  : AppColors.textPrimary,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Split among
            RichText(
              text: TextSpan(
                text: 'Split among ',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                children: [
                  TextSpan(
                    text: '( Tap to unselect )',
                    style: TextStyle(color: AppColors.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_members.isEmpty)
              const Center(child: CircularProgressIndicator())
            else
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _members.length,
                  itemBuilder: (context, index) {
                    final member = _members[index];
                    final currentUser = ref.read(authStateProvider).valueOrNull;
                    final isYou = member.userId == currentUser?.id;

                    // Simple logic for equally split for demo
                    final amt = double.tryParse(_amtCtrl.text) ?? 0.0;
                    final splitAmt = amt / _members.length;

                    return Container(
                      width: 80,
                      margin: const EdgeInsets.only(right: AppSpacing.md),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.primary, width: 2),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusLg,
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(AppSpacing.radiusMd),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                isYou ? 'You' : 'Member',
                                style: TextStyle(
                                  color: AppColors.surface,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                _splitType == 'Equally'
                                    ? splitAmt.toStringAsFixed(0)
                                    : '0',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: AppSpacing.xl),

            // Bottom actions (Add image, Scan bill, Date)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Add image'),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFF0F0FF),
                    foregroundColor: const Color(0xFF5C6BC0),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.receipt_long),
                  label: const Text('Scan bill'),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFE8F5E9),
                    foregroundColor: const Color(0xFF388E3C),
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (date != null) {
                      setState(() => _selectedDate = date);
                    }
                  },
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(DateHelpers.formatFullDate(_selectedDate)),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFE3F2FD),
                    foregroundColor: const Color(0xFF1976D2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitExpense,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.textPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                  ),
                ),
                child: _isLoading
                    ? CircularProgressIndicator(color: AppColors.surface)
                    : Text(
                        'Submit expense',
                        style: TextStyle(fontSize: 18, color: AppColors.surface),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitExpense() async {
    final desc = _descCtrl.text.trim();
    final amt = double.tryParse(_amtCtrl.text.trim());
    if (desc.isEmpty || amt == null || amt <= 0 || _members.isEmpty) return;

    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      // Calculate splits
      List<Map<String, dynamic>> splits = [];
      if (_splitType == 'Equally') {
        final splitAmt = amt / _members.length;
        splits = _members
            .map((m) => {'userId': m.userId, 'amountOwed': splitAmt})
            .toList();
      } else {
        // Fallback or handle unequal/item-wise if customSplits has data.
        // For now, if unhandled, just default to equally to avoid crash.
        final splitAmt = amt / _members.length;
        splits = _members
            .map((m) => {'userId': m.userId, 'amountOwed': splitAmt})
            .toList();
      }

      await ref
          .read(expenseRepositoryProvider)
          .createGroupExpense(
            userId: user.id,
            groupId: widget.group.id,
            description: desc,
            amount: amt,
            category: _selectedCategory,
            date: _selectedDate,
            splitType: _splitType.toLowerCase(),
            splits: splits,
          );

      ref.invalidate(monthlyExpensesProvider);
      if (mounted) Navigator.pop(context); // Close the sheet
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
