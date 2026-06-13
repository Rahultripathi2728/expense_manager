import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../groups/data/group_repository.dart';
import 'group_expense_sheet.dart';

class AddExpenseOptionsSheet extends ConsumerWidget {
  const AddExpenseOptionsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userGroupsAsync = ref.watch(userGroupsProvider);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Add Expense',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          Text(
            'Choose an option to add your expense',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Add to a recent group
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F2FF), // Light blue-ish
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0xFFFFE4E1), // Light pinkish
                      child: Icon(Icons.groups, color: Color(0xFFD87093)),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add to a recent group',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Tap a group below',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                userGroupsAsync.when(
                  data: (groups) {
                    if (groups.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.only(top: AppSpacing.sm),
                        child: Text('No recent groups found.'),
                      );
                    }
                    return SizedBox(
                      height: 80,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: groups.length,
                        itemBuilder: (context, index) {
                          final group = groups[index];
                          return GestureDetector(
                            onTap: () {
                              Navigator.pop(context); // Close options sheet
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                builder: (_) => GroupExpenseSheet(group: group),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(
                                right: AppSpacing.md,
                              ),
                              child: Column(
                                children: [
                                  CircleAvatar(
                                    radius: 28,
                                    backgroundColor: AppColors.surface,
                                    child: const Icon(
                                      Icons.home,
                                      color: Color(0xFFFFA07A),
                                    ), // Use home icon for demo
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    group.name,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (e, st) => Text('Error: $e'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Outside groups
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9), // Light green
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFC8E6C9), // Slightly darker green
                  child: Icon(Icons.person_add, color: Color(0xFF388E3C)),
                ),
                const SizedBox(width: AppSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Outside groups',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Quick split with friends',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Add Expense from UPI apps
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0), // Light orange
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(
                        0xFFFFE0B2,
                      ), // Slightly darker orange
                      child: Icon(Icons.payment, color: Color(0xFFE65100)),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add Expense from UPI apps',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Import from your UPI apps',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _UpiAppIcon(
                      name: 'PhonePe',
                      iconData: Icons.currency_rupee,
                    ), // Placeholder for PhonePe icon
                    _UpiAppIcon(
                      name: 'Google Pay',
                      iconData: Icons.g_mobiledata,
                    ), // Placeholder for Google Pay icon
                    _UpiAppIcon(
                      name: 'Paytm',
                      iconData: Icons.payment,
                    ), // Placeholder for Paytm icon
                    _UpiAppIcon(
                      name: 'Cred',
                      iconData: Icons.credit_card,
                    ), // Placeholder for Cred icon
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

class _UpiAppIcon extends StatelessWidget {
  final String name;
  final IconData iconData;

  const _UpiAppIcon({required this.name, required this.iconData});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: AppColors.surface,
          child: Icon(iconData, color: AppColors.primary, size: 28),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          name,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
