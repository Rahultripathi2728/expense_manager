import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:appwrite/appwrite.dart';
import '../../../../app/constants/app_constants.dart';
import '../../../../core/appwrite_client.dart';
import '../../../../core/utils/date_helpers.dart';
import '../../../../core/utils/row_helpers.dart';
import '../../../expenses/presentation/utils/category_icon_helper.dart';
import '../../../expenses/domain/expense_model.dart';
import '../../../expenses/domain/expense_split_model.dart';
import '../../../expenses/domain/expense_item_model.dart';
import '../../../expenses/data/expense_repository.dart';
import '../../../groups/domain/group_model.dart';
import '../../../profile/domain/profile_model.dart';
import '../../../auth/data/auth_repository.dart';

import '../../../settlement/presentation/settlement_page.dart';

// Providers for fetching additional details for the card

final expenseSplitsProvider = FutureProvider.family<List<ExpenseSplit>, String>(
  (ref, expenseId) async {
    return ref.read(expenseRepositoryProvider).getExpenseSplits(expenseId);
  },
);

final expenseItemsProvider = FutureProvider.family<List<ExpenseItem>, String>(
  (ref, expenseId) async {
    return ref.read(expenseRepositoryProvider).getExpenseItems(expenseId);
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
  final double? overrideShareAmount;
  final double? personalItemAmount;

  const CalendarExpenseCard({
    super.key, 
    required this.expense,
    this.overrideShareAmount,
    this.personalItemAmount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGroup = expense.isGroup;
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

    final groupBalancesAsync = isGroup && expense.groupId != null
        ? ref.watch(groupBalancesProvider(expense.groupId!))
        : const AsyncValue.data(null);

    final splits = splitsAsync.valueOrNull ?? [];

    final balancesData = groupBalancesAsync.valueOrNull;
    bool isFullySettled = expense.isSettled;
    bool isPartiallySettled = false;
    bool isLocked = expense.isSettled;
    int settledDebtors = 0;
    int totalDebtors = 0;

    if (isGroup && balancesData != null) {
      isFullySettled = balancesData.isExpenseFullySettled(expense);
      isPartiallySettled = balancesData.isExpensePartiallySettled(expense);
      isLocked = balancesData.isExpenseLocked(expense);
      settledDebtors = balancesData.getSettledDebtorsCount(expense);
      totalDebtors = balancesData.getTotalDebtorsCount(expense);
    }

    bool isMyShareSettled = false;
    if (isGroup && !isFullySettled && currentUser != null && balancesData != null && expense.userId != currentUser.id) {
      final remaining = balancesData.remainingOwedPerUserPerExpense[expense.id]?[currentUser.id];
      if (remaining != null && remaining <= AppConstants.splitEpsilon) {
        isMyShareSettled = true;
      }
    }

    bool isVirtuallyPersonal = false;
    if (isGroup && splits.isNotEmpty && currentUser != null) {
      final mySplit = splits.where((s) => s.userId == currentUser.id).firstOrNull;
      if (mySplit != null && mySplit.amountOwed == expense.amount && expense.amount > 0) {
        isVirtuallyPersonal = true;
      }
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
              CategoryIconHelper.buildBadge(expense.category, size: 48, iconSize: 22),
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
                          child: Row(
                            children: [
                              if (isLocked || (isGroup && currentUser != null && expense.userId != currentUser.id))
                                Padding(
                                  padding: const EdgeInsets.only(right: 6.0),
                                  child: Icon(Icons.lock_outline, size: 14, color: AppColors.textSecondary),
                                ),
                              Expanded(
                                child: Text(
                                  expense.description,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: isFullySettled ? AppColors.textSecondary : AppColors.textPrimary,
                                    decoration: isFullySettled
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          DateHelpers.formatCurrency(expense.amount),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isFullySettled ? AppColors.textSecondary : AppColors.textPrimary,
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
                              if (isGroup && groupAsync.valueOrNull != null) ...[
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
                                ),
                                if (isVirtuallyPersonal)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Personal',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                if (personalItemAmount != null && personalItemAmount! > 0 && !isVirtuallyPersonal)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Personal Items: ${DateHelpers.formatCurrency(personalItemAmount!)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ] else if (!isGroup) ...[
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
                              ],

                              // Settled Badge (Full)
                              if (isFullySettled)
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
                                )
                              else if (isPartiallySettled)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7), // Faint amber
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.pie_chart_outline,
                                        size: 12,
                                        color: Color(0xFFD97706),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        totalDebtors > 0
                                            ? 'Partially Settled ($settledDebtors/$totalDebtors)'
                                            : 'Partially Settled',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFFD97706),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              if (isMyShareSettled)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.check,
                                        size: 12,
                                        color: Color(0xFF16A34A),
                                      ),
                                      SizedBox(width: 3),
                                      Text(
                                        'Your share settled',
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
                                isVirtuallyPersonal
                                  ? 'Paid by ${currentUser?.id == expense.userId ? 'You' : (profileAsync.valueOrNull?.fullName.split(' ').first ?? '...')}'
                                  : 'by ${currentUser?.id == expense.userId ? 'You' : (profileAsync.valueOrNull?.fullName.split(' ').first ?? '...')}',
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

                              final shareAmount = overrideShareAmount ?? mySplit.amountOwed;
                              final isUserPayer = expense.userId == currentUser.id;

                              return Text(
                                isUserPayer
                                    ? 'You paid full'
                                    : (isMyShareSettled
                                        ? 'Share: ${DateHelpers.formatCurrency(shareAmount)} (Paid)'
                                        : 'Share: ${DateHelpers.formatCurrency(shareAmount)}'),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isMyShareSettled ? const Color(0xFF16A34A) : AppColors.textSecondary,
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
