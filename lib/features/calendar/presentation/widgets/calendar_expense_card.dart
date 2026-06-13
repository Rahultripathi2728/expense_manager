import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:appwrite/appwrite.dart';
import '../../../../app/constants/app_constants.dart';
import '../../../../core/appwrite_client.dart';
import '../../../../core/utils/date_helpers.dart';
import '../../../../core/utils/row_helpers.dart';
import '../../../../shared/services/categorize_service.dart';
import '../../../expenses/domain/expense_model.dart';
import '../../../expenses/domain/expense_split_model.dart';
import '../../../expenses/data/expense_repository.dart';
import '../../../groups/domain/group_model.dart';
import '../../../profile/domain/profile_model.dart';
import '../../../auth/data/auth_repository.dart';

// Providers for fetching additional details for the card

final expenseSplitsProvider = FutureProvider.family<List<ExpenseSplit>, String>(
  (ref, expenseId) async {
    return ref.read(expenseRepositoryProvider).getExpenseSplits(expenseId);
  },
);

final groupByIdProvider = FutureProvider.family<Group?, String>((
  ref,
  groupId,
) async {
  final tablesDB = ref.read(appwriteTablesDBProvider);
  try {
    final doc = await tablesDB.getRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.groupsCollection,
      rowId: groupId,
    );
    return Group.fromMap(doc.dataWithId);
  } catch (_) {
    return null;
  }
});

final profileByIdProvider = FutureProvider.family<Profile?, String>((
  ref,
  userId,
) async {
  final tablesDB = ref.read(appwriteTablesDBProvider);
  try {
    final res = await tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.profilesCollection,
      queries: [Query.equal('userId', userId)],
    );
    if (res.rows.isEmpty) return null;
    return Profile.fromMap(res.rows.first.dataWithId);
  } catch (_) {
    return null;
  }
});

class CalendarExpenseCard extends ConsumerWidget {
  final Expense expense;

  const CalendarExpenseCard({super.key, required this.expense});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGroup = expense.isGroup;
    final isSettled = isGroup && expense.isSettled;

    // Asynchronously fetch details
    final currentUser = ref.watch(authStateProvider).valueOrNull;
    final profileAsync = ref.watch(profileByIdProvider(expense.userId));

    AsyncValue<Group?> groupAsync = const AsyncValue.data(null);
    if (isGroup && expense.groupId != null) {
      groupAsync = ref.watch(groupByIdProvider(expense.groupId!));
    }

    AsyncValue<List<ExpenseSplit>> splitsAsync = const AsyncValue.data([]);
    if (isGroup) {
      splitsAsync = ref.watch(expenseSplitsProvider(expense.id));
    }

    return GestureDetector(
      onTap: () {
        context.push('/expense-detail', extra: expense);
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon Container
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    CategorizeService.iconForCategory(expense.category),
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and Total Amount
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            expense.description,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isSettled ? AppColors.textSecondary : AppColors.textPrimary,
                              decoration: isSettled
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          DateHelpers.formatCurrency(expense.amount),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isSettled ? AppColors.textSecondary : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Badges and Share
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Badges side
                        Expanded(
                          child: Wrap(
                            spacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              // Group Badge
                              if (isGroup && groupAsync.valueOrNull != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceVariant,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.person_outline,
                                        size: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        groupAsync.valueOrNull!.name,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else if (!isGroup)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceVariant,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Personal',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),

                              // Settled Badge
                              if (isSettled)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFFDCFCE7,
                                    ), // Faint green
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.check_circle_outline,
                                        size: 12,
                                        color: Color(0xFF16A34A),
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Settled',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF16A34A),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              // Creator text
                              Text(
                                'by ${currentUser?.id == expense.userId ? 'You' : (profileAsync.valueOrNull?.fullName.split(' ').first ?? '...')}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Share side
                        if (isGroup)
                          splitsAsync.when(
                            data: (splits) {
                              if (currentUser == null) {
                                return const SizedBox.shrink();
                              }
                              final mySplit = splits
                                  .where((s) => s.userId == currentUser.id)
                                  .firstOrNull;
                              if (mySplit == null) {
                                return const SizedBox.shrink();
                              }

                              return Text(
                                'Share: ${DateHelpers.formatCurrency(mySplit.amountOwed)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              );
                            },
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
