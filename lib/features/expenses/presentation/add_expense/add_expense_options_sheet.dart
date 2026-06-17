import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../groups/data/group_repository.dart';
import 'add_expense_screen.dart';

class AddExpenseOptionsSheet extends ConsumerWidget {
  final DateTime? initialDate;
  const AddExpenseOptionsSheet({super.key, this.initialDate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(userGroupsProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Close (X) button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Add expense',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Subtitle
              Text(
                'Add expense to group',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              // Group List
              groupsAsync.when(
                data: (groups) {
                  if (groups.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        'No groups found. Create a group first.',
                        style: TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 13,
                        ),
                      ),
                    );
                  }
                  return SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: groups.length,
                      itemBuilder: (context, index) {
                        final group = groups[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 20),
                          child: GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      AddExpenseScreen(group: group, initialDate: initialDate),
                                ),
                              );
                            },
                            child: Column(
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3F3F3),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.borderLight,
                                      width: 1,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.group_outlined,
                                    color: AppColors.textPrimary,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  group.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
                loading: () => SizedBox(
                  height: 100,
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.textPrimary),
                  ),
                ),
                error: (err, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'Error: $err',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Add Expense as Personal Option
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddExpenseScreen(group: null, initialDate: initialDate),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9F9F9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderLight, width: 1),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.borderLight,
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          Icons.account_balance_wallet_outlined,
                          color: AppColors.textPrimary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'Add expense as personal',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.chevron_right, color: AppColors.textTertiary),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
