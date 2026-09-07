import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:expense_manager/app/theme/theme_provider.dart';
import 'package:appwrite/appwrite.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/constants/app_constants.dart';
import '../../../core/appwrite_client.dart';
import '../../../core/utils/date_helpers.dart';
import '../../expenses/data/expense_repository.dart';
import '../../groups/data/group_repository.dart';
import '../data/settlement_repository.dart';
import '../domain/balance_calculator.dart';
import '../domain/settlement_model.dart';
import '../../expenses/domain/expense_model.dart';
import '../../expenses/domain/expense_split_model.dart';
import '../../profile/domain/profile_model.dart';
import '../../auth/data/auth_repository.dart';
import '../../../shared/widgets/custom_error_widget.dart';
import '../../../shared/widgets/skeleton_loading_card.dart';

import '../engine/models/group_ledger_state.dart';
import '../engine/providers/group_ledger_provider.dart';

final groupBalancesProvider = FutureProvider.family<GroupBalanceData, String>((
  ref,
  groupId,
) async {
  final ledger = await ref.watch(groupLedgerProvider(groupId).future);

  return GroupBalanceData(
    membersCount: ledger.membersCount,
    unsettledExpensesCount: ledger.unsettledExpensesCount,
    totalUnsettledAmount: ledger.totalUnsettledAmount,
    netBalances: ledger.netBalances,
    paidAmounts: ledger.billsPaidByMember,
    shareAmounts: ledger.billShareByMember,
    transactions: ledger.transactions
        .map((t) => SimplifiedTransaction(
              fromUserId: t.fromUserId,
              toUserId: t.toUserId,
              amount: t.amount,
            ))
        .toList(),
    profiles: ledger.profiles,
    lastSettlement: ledger.lastSettlement,
    unsettledExpenses: ledger.unsettledExpenses,
    splitsByExpense: ledger.splitsByExpense,
    remainingOwedPerUserPerExpense: {},
    settlements: ledger.settlements,
  );
});

class MemberShareItem {
  final Expense expense;
  final double shareAmount;
  final String payerName;
  final bool isPayer;

  const MemberShareItem({
    required this.expense,
    required this.shareAmount,
    required this.payerName,
    required this.isPayer,
  });
}

class GroupBalanceData {
  final int membersCount;
  final int unsettledExpensesCount;
  final double totalUnsettledAmount;
  final Map<String, double> netBalances;
  final Map<String, double> paidAmounts;
  final Map<String, double> shareAmounts;
  final List<SimplifiedTransaction> transactions;
  final Map<String, Profile> profiles;
  final Settlement? lastSettlement;
  final List<Expense> unsettledExpenses;
  final Map<String, List<ExpenseSplit>> splitsByExpense;
  final Map<String, Map<String, double>> remainingOwedPerUserPerExpense;
  final List<Settlement> settlements;

  GroupBalanceData({
    required this.membersCount,
    required this.unsettledExpensesCount,
    required this.totalUnsettledAmount,
    required this.netBalances,
    required this.paidAmounts,
    required this.shareAmounts,
    required this.transactions,
    required this.profiles,
    this.lastSettlement,
    required this.unsettledExpenses,
    required this.splitsByExpense,
    required this.remainingOwedPerUserPerExpense,
    this.settlements = const [],
  });

  /// Returns the settlement status for an expense.
  ExpenseSettlementStatus getExpenseSettlementStatus(Expense expense) {
    if (expense.isSettled) return ExpenseSettlementStatus.fullySettled;

    final splits = splitsByExpense[expense.id] ?? [];
    final debtorIds = splits
        .where((s) => s.userId != expense.userId && s.isIncluded)
        .map((s) => s.userId)
        .toSet();

    final settlementsForExp = settlements
        .where((s) => s.settledExpenseIds.contains(expense.id))
        .toList();

    if (settlementsForExp.isEmpty) {
      return ExpenseSettlementStatus.unsettled;
    }

    if (debtorIds.isEmpty) {
      return ExpenseSettlementStatus.fullySettled;
    }

    final settledDebtorIds = settlementsForExp.map((s) => s.fromUserId).toSet();
    final allSettled = debtorIds.every(settledDebtorIds.contains);

    if (allSettled) {
      return ExpenseSettlementStatus.fullySettled;
    } else {
      return ExpenseSettlementStatus.partiallySettled;
    }
  }

  /// True ONLY when all included debtors have settled their share.
  bool isExpenseFullySettled(Expense expense) {
    return getExpenseSettlementStatus(expense) == ExpenseSettlementStatus.fullySettled;
  }

  /// True when some participants have paid, but others are still pending.
  bool isExpensePartiallySettled(Expense expense) {
    return getExpenseSettlementStatus(expense) == ExpenseSettlementStatus.partiallySettled;
  }

  /// An expense is locked if it is either partially or fully settled.
  bool isExpenseLocked(Expense expense) {
    final status = getExpenseSettlementStatus(expense);
    return status == ExpenseSettlementStatus.partiallySettled ||
        status == ExpenseSettlementStatus.fullySettled;
  }

  bool isExpensePartiallyOrFullySettled(Expense expense) {
    return isExpenseLocked(expense);
  }

  int getSettledDebtorsCount(Expense expense) {
    final splits = splitsByExpense[expense.id] ?? [];
    final debtorIds = splits
        .where((s) => s.userId != expense.userId && s.isIncluded)
        .map((s) => s.userId)
        .toSet();
    final settlementsForExp = settlements
        .where((s) => s.settledExpenseIds.contains(expense.id))
        .toList();
    final settledDebtors = settlementsForExp
        .map((s) => s.fromUserId)
        .where(debtorIds.contains)
        .toSet();
    return settledDebtors.length;
  }

  int getTotalDebtorsCount(Expense expense) {
    final splits = splitsByExpense[expense.id] ?? [];
    return splits.where((s) => s.userId != expense.userId && s.isIncluded).length;
  }

  /// Get the settlement recorded specifically for a debtor paying the payer for an expense
  Settlement? getSettlementForExpenseAndDebtor(String expenseId, String debtorId, String payerId) {
    for (final s in settlements) {
      if (s.fromUserId == debtorId && s.toUserId == payerId && s.settledExpenseIds.contains(expenseId)) {
        return s;
      }
    }
    return null;
  }

  List<Expense> getPaidExpenses(String userId) {
    return unsettledExpenses.where((e) => e.userId == userId).toList();
  }

  List<MemberShareItem> getSharedExpenses(String userId) {
    final List<MemberShareItem> shares = [];
    for (final exp in unsettledExpenses) {
      final splits = splitsByExpense[exp.id] ?? [];
      final userSplit = splits.where((s) => s.userId == userId).toList();

      double shareAmt = 0.0;
      bool isIncluded = false;
      if (userSplit.isNotEmpty) {
        isIncluded = userSplit.first.isIncluded;
        shareAmt = isIncluded ? userSplit.first.amountOwed : 0.0;
      } else if (membersCount > 0) {
        isIncluded = true;
        shareAmt = exp.amount / membersCount;
      }

      if (isIncluded && shareAmt > 0) {
        final payerName = profiles[exp.userId]?.fullName ?? 'Member';
        shares.add(
          MemberShareItem(
            expense: exp,
            shareAmount: shareAmt,
            payerName: payerName,
            isPayer: exp.userId == userId,
          ),
        );
      }
    }
    return shares;
  }

  List<Settlement> getSettlementsPaid(String userId) {
    final activeExpIds = unsettledExpenses.map((e) => e.id).toSet();
    return settlements.where((s) => s.fromUserId == userId && s.settledExpenseIds.any((id) => activeExpIds.contains(id))).toList();
  }

  List<Settlement> getSettlementsReceived(String userId) {
    final activeExpIds = unsettledExpenses.map((e) => e.id).toSet();
    return settlements.where((s) => s.toUserId == userId && s.settledExpenseIds.any((id) => activeExpIds.contains(id))).toList();
  }
}

class SettlementPage extends ConsumerStatefulWidget {
  const SettlementPage({super.key});

  @override
  ConsumerState<SettlementPage> createState() => _SettlementPageState();
}

class _SettlementPageState extends ConsumerState<SettlementPage> with WidgetsBindingObserver {
  String? selectedGroupId;
  bool settling = false;
  bool _initialGroupSet = false;

  SimplifiedTransaction? _pendingTransaction;
  List<String>? _pendingExpIds;
  bool _showingConfirmationDialog = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _handleAppResumed();
    }
  }

  void _handleAppResumed() {
    if (_pendingTransaction != null && !_showingConfirmationDialog && mounted) {
      _showResumptionConfirmationDialog(_pendingTransaction!);
    }
  }

  Future<void> _payViaUPI(SimplifiedTransaction tx, Profile? recipient, List<String> expIds) async {
    final toName = recipient?.fullName ?? 'Member';
    final upiId = recipient?.upiId ?? '';

    if (upiId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$toName has not set a UPI ID yet. Please ask them to add it in Profile settings.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final uri = Uri.parse(
      'upi://pay?pa=$upiId&pn=${Uri.encodeComponent(toName)}&am=${tx.amount.toStringAsFixed(2)}&cu=INR&tn=Settlement%20via%20SplitPro',
    );

    _pendingTransaction = tx;
    _pendingExpIds = expIds;

    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open UPI payment app. Please make payment manually.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No UPI application found on device.')),
        );
      }
    }
  }

  Future<void> _performSettlement(SimplifiedTransaction tx, List<String> expIds) async {
    if (settling) return;
    setState(() => settling = true);
    try {
      final repo = ref.read(settlementRepositoryProvider);
      await repo.settleBalancesLocalFallback(
        selectedGroupId!,
        tx.fromUserId,
        tx.toUserId,
        tx.amount,
        expIds,
      );

      // In-app notification to recipient
      try {
        final currentUser = ref.read(authStateProvider).valueOrNull;
        final payerName = currentUser?.name.isNotEmpty == true ? currentUser!.name : 'Group Member';
        final tablesDB = ref.read(appwriteTablesDBProvider);
        await tablesDB.createRow(
          databaseId: AppConstants.databaseId,
          tableId: AppConstants.notificationsCollection,
          rowId: ID.unique(),
          data: {
            'userId': tx.toUserId,
            'title': '💰 Payment Received & Settled',
            'body': '$payerName marked ₹${tx.amount.toStringAsFixed(0)} as paid and settled with you.',
            'type': 'settled',
            'isRead': false,
            'createdAt': DateTime.now().toIso8601String(),
          },
        );
      } catch (_) {}

      ref.invalidate(groupBalancesProvider(selectedGroupId!));
      ref.invalidate(monthlyExpensesProvider);

      if (mounted) {
        HapticHelper.mediumTap();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Settled ₹${tx.amount.toStringAsFixed(0)} successfully!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Settlement failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => settling = false);
      }
    }
  }

  void _showResumptionConfirmationDialog(SimplifiedTransaction tx) {
    if (_showingConfirmationDialog) return;
    _showingConfirmationDialog = true;
    
    final toName = ref.read(groupBalancesProvider(selectedGroupId!)).valueOrNull?.profiles[tx.toUserId]?.fullName ?? 'User';
    final expIds = _pendingExpIds ?? [];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          ),
          title: Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: AppColors.success,
                size: AppSpacing.iconLg,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Verify UPI Payment',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    height: 1.4,
                  ),
                  children: [
                    const TextSpan(text: 'We opened your UPI app to transfer '),
                    TextSpan(
                      text: DateHelpers.formatCurrency(tx.amount),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const TextSpan(text: ' to '),
                    TextSpan(
                      text: toName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const TextSpan(text: '.\n\nDid you successfully complete the payment?'),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _pendingTransaction = null;
                _pendingExpIds = null;
                _showingConfirmationDialog = false;
                Navigator.pop(ctx);
              },
              child: Text(
                'No, Cancel',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.textPrimary,
                foregroundColor: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
              ),
              onPressed: settling
                  ? null
                  : () {
                      _pendingTransaction = null;
                      _pendingExpIds = null;
                      _showingConfirmationDialog = false;
                      Navigator.pop(ctx);
                      _performSettlement(tx, expIds);
                    },
              child: const Text(
                'Yes, Settle',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    final groupsAsync = ref.watch(userGroupsProvider);
    final user = ref.watch(authStateProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Settlements',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Settlement History',
            onPressed: () {
              if (selectedGroupId != null) {
                context.push('/settlement-history', extra: selectedGroupId);
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: groupsAsync.when(
        loading: () =>
            const Padding(padding: EdgeInsets.all(AppSpacing.lg), child: SkeletonGroupList(itemCount: 3)),
        error: (e, _) => CustomErrorWidget(
          error: e,
          onRetry: () => ref.refresh(userGroupsProvider),
        ),
        data: (groups) {
          if (groups.isEmpty) {
            return Center(
              child: Text(
                'You are not part of any groups.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }

          // Set initial group only once
          if (!_initialGroupSet &&
              selectedGroupId == null &&
              groups.isNotEmpty) {
            _initialGroupSet = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => selectedGroupId = groups.first.id);
            });
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Horizontal Group List
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: SizedBox(
                  height: 85,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: groups.length,
                    itemBuilder: (context, index) {
                      final group = groups[index];
                      final isSelected = group.id == selectedGroupId;

                      // Extract initials
                      final parts = group.name.trim().split(' ');
                      String initials = 'G';
                      if (parts.isNotEmpty) {
                        if (parts.length > 1) {
                          initials = (parts[0][0] + parts[1][0]).toUpperCase();
                        } else if (parts[0].isNotEmpty) {
                          initials = parts[0][0].toUpperCase();
                        }
                      }

                      return Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedGroupId = group.id;
                            });
                          },
                          child: Column(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.borderLight,
                                    width: isSelected ? 2.5 : 1,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: AppColors.primary.withValues(alpha: 0.35),
                                            blurRadius: 10,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: CircleAvatar(
                                  radius: 24,
                                  backgroundColor: isSelected
                                      ? AppColors.primary
                                      : AppColors.surfaceVariant,
                                  child: Text(
                                    initials,
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : AppColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                group.name.split(' ').first,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isSelected
                                      ? AppColors.textPrimary
                                      : AppColors.textSecondary,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Divider(height: 1, color: AppColors.borderLight),

              // Settlement Content
              Expanded(
                child: selectedGroupId == null
                    ? const SizedBox.shrink()
                    : RefreshIndicator(
                        color: AppColors.surface,
                        backgroundColor: AppColors.textPrimary,
                        strokeWidth: 3,
                        onRefresh: () async {
                          if (selectedGroupId != null) {
                            ref.invalidate(groupBalancesProvider(selectedGroupId!));
                          }
                          await Future.delayed(const Duration(milliseconds: 600));
                        },
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: ref
                            .watch(groupBalancesProvider(selectedGroupId!))
                            .when(
                              loading: () => const Padding(
                                padding: EdgeInsets.only(top: 40),
                                child: SkeletonList(itemCount: 3),
                              ),
                              error: (err, _) => CustomErrorWidget(
                                error: err,
                                onRetry: () => ref.refresh(groupBalancesProvider(selectedGroupId!)),
                              ),
                              data: (data) {
                                final myUserId = user?.id ?? '';
                                final myNet = data.netBalances[myUserId] ?? 0.0;

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Room summary info card
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: AppColors.surface,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: AppColors.borderLight,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF3F3F3),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Icon(
                                              Icons.people_outline,
                                              color: AppColors.textPrimary,
                                              size: 24,
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                groups
                                                    .firstWhere(
                                                      (g) =>
                                                          g.id ==
                                                          selectedGroupId,
                                                      orElse: () =>
                                                          groups.first,
                                                    )
                                                    .name,
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                data.unsettledExpensesCount > 0
                                                    ? '${data.membersCount} members • ${data.unsettledExpensesCount} ${data.unsettledExpensesCount == 1 ? 'expense' : 'expenses'} since last settlement'
                                                    : '${data.membersCount} members • All expenses settled',
                                                style: TextStyle(
                                                  color: AppColors.textSecondary,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),

                                    // Last settlement banner (if any)
                                    if (data.lastSettlement != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE2FBE7),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFC7F3D0),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.check_circle_outline,
                                              color: Color(0xFF22C55E),
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Last Settlement: ${DateHelpers.formatFullDate(data.lastSettlement!.createdAt)}, ${DateHelpers.formatTime(data.lastSettlement!.createdAt)} by ${data.profiles[data.lastSettlement!.fromUserId]?.fullName.split(' ').first ?? 'User'} • ${DateHelpers.formatCurrency(data.lastSettlement!.amount)}',
                                                style: const TextStyle(
                                                  color: Color(0xFF22C55E),
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    const SizedBox(height: AppSpacing.lg),

                                    // Member Balances Header
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.account_balance_wallet_rounded,
                                          size: 20,
                                          color: AppColors.textPrimary,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Member Balances',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: AppSpacing.md),

                                    // Members Net Balance list
                                    ListView.builder(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      itemCount: data.profiles.length,
                                      itemBuilder: (context, idx) {
                                        final uId = data.profiles.keys
                                            .elementAt(idx);
                                        final p = data.profiles[uId]!;
                                        final isMe = uId == myUserId;
                                        final net =
                                            data.netBalances[uId] ?? 0.0;
                                        final paid =
                                            data.paidAmounts[uId] ?? 0.0;
                                        final share =
                                            data.shareAmounts[uId] ?? 0.0;
                                        final paidExps = data.getPaidExpenses(uId);
                                        final sharedExps = data.getSharedExpenses(uId);
                                        final setsPaid = data.getSettlementsPaid(uId);
                                        final setsRecv = data.getSettlementsReceived(uId);
                                        final totalSetsPaid = setsPaid.fold<double>(0.0, (sum, s) => sum + s.amount);
                                        final totalSetsRecv = setsRecv.fold<double>(0.0, (sum, s) => sum + s.amount);

                                        final isSettled = net.abs() < 0.05;
                                        final isGetsBack = net > 0.05;
                                        final badgeColor = isSettled
                                            ? const Color(0xFF6B7280)
                                            : (isGetsBack
                                                ? const Color(0xFF10B981)
                                                : AppColors.error);
                                        final badgeBg = badgeColor.withValues(alpha: 0.12);
                                        final badgeText = isSettled
                                            ? 'Settled (₹0)'
                                            : (isGetsBack
                                                ? '+ Gets back ${DateHelpers.formatCurrency(net)}'
                                                : '- Owes ${DateHelpers.formatCurrency(-net)}');

                                        return Container(
                                          margin: const EdgeInsets.only(
                                            bottom: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.surface,
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            border: Border.all(
                                              color: isMe
                                                  ? AppColors.primary.withValues(alpha: 0.35)
                                                  : AppColors.borderLight,
                                              width: isMe ? 1.5 : 1.0,
                                            ),
                                          ),
                                          child: Material(
                                            color: Colors.transparent,
                                            borderRadius: BorderRadius.circular(14),
                                            clipBehavior: Clip.antiAlias,
                                            child: Theme(
                                              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                              child: ExpansionTile(
                                                tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                                childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                                                leading: Container(
                                                  width: 40,
                                                  height: 40,
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      begin: Alignment.topLeft,
                                                      end: Alignment.bottomRight,
                                                      colors: [
                                                        AppColors.primary,
                                                        const Color(0xFF41A5FF),
                                                      ],
                                                    ),
                                                    shape: BoxShape.circle,
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: AppColors.primary.withValues(alpha: 0.25),
                                                        blurRadius: 6,
                                                        offset: const Offset(0, 2),
                                                      ),
                                                    ],
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      p.fullName.isNotEmpty
                                                          ? p.fullName.substring(0, 1).toUpperCase()
                                                          : 'U',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 16,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                title: Text(
                                                  isMe
                                                      ? '${p.fullName} (You)'
                                                      : p.fullName,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14.5,
                                                    color: AppColors.textPrimary,
                                                  ),
                                                ),
                                                subtitle: Text(
                                                  totalSetsPaid > 0
                                                      ? 'Paid ${DateHelpers.formatCurrency(paid)} (+${DateHelpers.formatCurrency(totalSetsPaid)} Settled) • Share ${DateHelpers.formatCurrency(share)}'
                                                      : 'Paid ${DateHelpers.formatCurrency(paid)} • Share ${DateHelpers.formatCurrency(share)}',
                                                  style: TextStyle(
                                                    color: AppColors.textSecondary,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                trailing: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: badgeBg,
                                                        borderRadius: BorderRadius.circular(8),
                                                        border: Border.all(color: badgeColor.withValues(alpha: 0.25), width: 1),
                                                      ),
                                                      child: Text(
                                                        badgeText,
                                                        style: TextStyle(
                                                          fontSize: 11.5,
                                                          fontWeight: FontWeight.bold,
                                                          color: badgeColor,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Icon(
                                                      Icons.keyboard_arrow_down_rounded,
                                                      color: AppColors.textSecondary,
                                                      size: 20,
                                                    ),
                                                  ],
                                                ),
                                                children: [
                                                  const Divider(height: 1),
                                                  const SizedBox(height: 10),

                                                  // ── Calculation / Hisaab Summary Box ──
                                                   Container(
                                                     padding: const EdgeInsets.all(12),
                                                     decoration: BoxDecoration(
                                                       color: AppColors.surfaceVariant.withValues(alpha: 0.4),
                                                       borderRadius: BorderRadius.circular(12),
                                                       border: Border.all(color: AppColors.borderLight),
                                                     ),
                                                     child: Column(
                                                       children: [
                                                         if (isSettled && paid == 0 && share == 0 && totalSetsPaid == 0) ...[
                                                           Row(
                                                             children: [
                                                               const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 16),
                                                               const SizedBox(width: 8),
                                                               Expanded(
                                                                 child: Text(
                                                                   'All bills are fully settled! No pending shares or dues.',
                                                                   style: TextStyle(
                                                                     fontSize: 12,
                                                                     fontWeight: FontWeight.w600,
                                                                     color: AppColors.textPrimary,
                                                                   ),
                                                                 ),
                                                               ),
                                                             ],
                                                           ),
                                                         ] else ...[
                                                           Row(
                                                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                             children: [
                                                               Text('Bills Paid:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                                               Text(
                                                                 DateHelpers.formatCurrency(paid),
                                                                 style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                                                               ),
                                                             ],
                                                           ),
                                                           if (totalSetsPaid > 0) ...[
                                                             const SizedBox(height: 4),
                                                             Row(
                                                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                               children: [
                                                                 Text('Settlements Paid (Cash):', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                                                 Text(
                                                                   '+ ${DateHelpers.formatCurrency(totalSetsPaid)}',
                                                                   style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                                                                 ),
                                                               ],
                                                             ),
                                                           ],
                                                           const SizedBox(height: 4),
                                                           Row(
                                                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                             children: [
                                                               Text('Share in Bills:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                                               Text(
                                                                 '- ${DateHelpers.formatCurrency(share)}',
                                                                 style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.error),
                                                               ),
                                                             ],
                                                           ),
                                                           if (totalSetsRecv > 0) ...[
                                                             const SizedBox(height: 4),
                                                             Row(
                                                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                               children: [
                                                                 Text('Settlements Received:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                                                 Text(
                                                                   '- ${DateHelpers.formatCurrency(totalSetsRecv)}',
                                                                   style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF3B82F6)),
                                                                 ),
                                                               ],
                                                             ),
                                                           ],
                                                           const Divider(height: 10),
                                                           Row(
                                                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                             children: [
                                                               Text('Net Balance:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                                               Text(
                                                                 badgeText,
                                                                 style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: badgeColor),
                                                               ),
                                                             ],
                                                           ),
                                                         ],
                                                       ],
                                                     ),
                                                   ),
                                                  const SizedBox(height: 12),

                                                  // ── Settlements Paid by Member ──
                                                  if (setsPaid.isNotEmpty) ...[
                                                    Row(
                                                      children: [
                                                        const Icon(Icons.check_circle_rounded, size: 15, color: Color(0xFF10B981)),
                                                        const SizedBox(width: 5),
                                                        Text(
                                                          'Settlements Paid by ${p.fullName.split(' ').first} (${setsPaid.length})',
                                                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 5),
                                                    ...setsPaid.map((s) {
                                                      final toName = data.profiles[s.toUserId]?.fullName ?? 'Member';
                                                      return Padding(
                                                        padding: const EdgeInsets.symmetric(vertical: 2.5, horizontal: 4),
                                                        child: Row(
                                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                          children: [
                                                            Expanded(
                                                              child: Text(
                                                                '• Paid to ${toName.split(' ').first} (${DateHelpers.formatDayMonth(s.createdAt)})',
                                                                style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                                                                overflow: TextOverflow.ellipsis,
                                                              ),
                                                            ),
                                                            Text(
                                                              DateHelpers.formatCurrency(s.amount),
                                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                    }),
                                                    const SizedBox(height: 10),
                                                  ],

                                                  // ── Bills Paid by Member ──
                                                  Row(
                                                    children: [
                                                      const Icon(Icons.arrow_upward_rounded, size: 15, color: Color(0xFF10B981)),
                                                      const SizedBox(width: 5),
                                                      Text(
                                                        'Bills Paid by ${p.fullName.split(' ').first} (${paidExps.length})',
                                                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 5),
                                                  if (paidExps.isEmpty)
                                                    Padding(
                                                      padding: const EdgeInsets.only(left: 20, bottom: 4),
                                                      child: Text(
                                                        'None (did not pay any active bill)',
                                                        style: TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: AppColors.textTertiary),
                                                      ),
                                                    )
                                                  else
                                                    ...paidExps.map((e) => Padding(
                                                          padding: const EdgeInsets.symmetric(vertical: 2.5, horizontal: 4),
                                                          child: Row(
                                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                            children: [
                                                              Expanded(
                                                                child: Text(
                                                                  '• ${e.description} (${DateHelpers.formatDayMonth(e.expenseDate)})',
                                                                  style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                                                                  overflow: TextOverflow.ellipsis,
                                                                ),
                                                              ),
                                                              Text(
                                                                DateHelpers.formatCurrency(e.amount),
                                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                                                              ),
                                                            ],
                                                          ),
                                                        )),

                                                  const SizedBox(height: 10),

                                                  // ── Member's Share in Bills (With Date & Payer) ──
                                                  Row(
                                                    children: [
                                                      Icon(Icons.arrow_downward_rounded, size: 15, color: AppColors.error),
                                                      const SizedBox(width: 5),
                                                      Text(
                                                        "${p.fullName.split(' ').first}'s Share in Bills (${sharedExps.length})",
                                                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 5),
                                                  if (sharedExps.isEmpty)
                                                    Padding(
                                                      padding: const EdgeInsets.only(left: 20, bottom: 4),
                                                      child: Text(
                                                        'No shared bills',
                                                        style: TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: AppColors.textTertiary),
                                                      ),
                                                    )
                                                  else
                                                    ...sharedExps.map((s) => Padding(
                                                          padding: const EdgeInsets.symmetric(vertical: 2.5, horizontal: 4),
                                                          child: Row(
                                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                            children: [
                                                              Expanded(
                                                                child: Text(
                                                                  '• ${s.expense.description} (${DateHelpers.formatDayMonth(s.expense.expenseDate)} • Paid by ${s.payerName.split(' ').first})',
                                                                  style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                                                                  overflow: TextOverflow.ellipsis,
                                                                ),
                                                              ),
                                                              Text(
                                                                DateHelpers.formatCurrency(s.shareAmount),
                                                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.error),
                                                              ),
                                                            ],
                                                          ),
                                                        )),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: AppSpacing.lg),

                                    // Balance Card
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF9F9F9),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: AppColors.borderLight,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Your Balance',
                                                style: TextStyle(
                                                  color: AppColors.textSecondary,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                myNet.abs() < 0.05
                                                    ? 'All settled up!'
                                                    : myNet > 0
                                                    ? 'You are owed ${DateHelpers.formatCurrency(myNet)}'
                                                    : 'You owe ${DateHelpers.formatCurrency(-myNet)}',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: myNet.abs() < 0.05
                                                      ? AppColors.textPrimary
                                                      : myNet > 0
                                                      ? const Color(0xFF22C55E)
                                                      : AppColors.error,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.xl),

                                    // WHO PAYS WHOM Section
                                    Text(
                                      'WHO PAYS WHOM',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.md),

                                    if (data.transactions.isEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 24,
                                        ),
                                        width: double.infinity,
                                        alignment: Alignment.center,
                                        child: const Column(
                                          children: [
                                            Icon(
                                              Icons.check_circle,
                                              color: Color(0xFF22C55E),
                                              size: 48,
                                            ),
                                            SizedBox(height: 12),
                                            Text(
                                              'All Settled Up!',
                                              style: TextStyle(
                                                color: Color(0xFF22C55E),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    else
                                      ListView.builder(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        itemCount: data.transactions.length,
                                        itemBuilder: (context, txIdx) {
                                          final tx = data.transactions[txIdx];
                                          final fromName =
                                              data
                                                  .profiles[tx.fromUserId]
                                                  ?.fullName ??
                                                      'User';
                                          final toName =
                                              data
                                                  .profiles[tx.toUserId]
                                                  ?.fullName ??
                                              'User';
                                          final isMyDebt = user?.id == tx.fromUserId;
                                          final isMyCredit = user?.id == tx.toUserId;

                                          return Container(
                                            padding: const EdgeInsets.all(12),
                                            margin: const EdgeInsets.only(
                                              bottom: 10,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.surface,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: isMyDebt
                                                    ? const Color(0xFFEF4444).withValues(alpha: 0.3)
                                                    : (isMyCredit
                                                        ? const Color(0xFF10B981).withValues(alpha: 0.3)
                                                        : AppColors.borderLight),
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Icon(
                                                      isMyDebt
                                                          ? Icons.arrow_circle_up_rounded
                                                          : (isMyCredit
                                                              ? Icons.arrow_circle_down_rounded
                                                              : Icons.arrow_forward),
                                                      color: isMyDebt
                                                          ? const Color(0xFFEF4444)
                                                          : (isMyCredit
                                                              ? const Color(0xFF10B981)
                                                              : AppColors.textSecondary),
                                                      size: 18,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: RichText(
                                                        text: TextSpan(
                                                          style: TextStyle(
                                                            color: AppColors.textPrimary,
                                                            fontSize: 14,
                                                          ),
                                                          children: [
                                                            TextSpan(
                                                              text: fromName
                                                                  .split(' ')
                                                                  .first,
                                                              style:
                                                                  const TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                  ),
                                                            ),
                                                            const TextSpan(
                                                              text: ' pays ',
                                                            ),
                                                            TextSpan(
                                                              text: toName
                                                                  .split(' ')
                                                                  .first,
                                                              style:
                                                                  const TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                  ),
                                                            ),
                                                            const TextSpan(
                                                              text: ' ',
                                                            ),
                                                            TextSpan(
                                                              text:
                                                                  DateHelpers.formatCurrency(
                                                                    tx.amount,
                                                                  ),
                                                              style:
                                                                  TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    color: isMyDebt
                                                                        ? const Color(0xFFEF4444)
                                                                        : (isMyCredit
                                                                            ? const Color(0xFF10B981)
                                                                            : Colors.black),
                                                                  ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                    if (isMyDebt)
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 2,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                                                          borderRadius: BorderRadius.circular(6),
                                                        ),
                                                        child: const Text(
                                                          'You Owe',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.bold,
                                                            color: Color(0xFFEF4444),
                                                          ),
                                                        ),
                                                      )
                                                    else if (isMyCredit)
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 2,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                                          borderRadius: BorderRadius.circular(6),
                                                        ),
                                                        child: const Text(
                                                          'You Receive',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.bold,
                                                            color: Color(0xFF10B981),
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                if (isMyDebt) ...[
                                                  const SizedBox(height: 10),
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: OutlinedButton.icon(
                                                          onPressed: settling
                                                              ? null
                                                              : () {
                                                                  final toProfile = data.profiles[tx.toUserId];
                                                                  final expIds = data.unsettledExpenses
                                                                      .where((e) => e.userId == tx.toUserId)
                                                                      .map((e) => e.id)
                                                                      .toList();
                                                                  _payViaUPI(tx, toProfile, expIds);
                                                                },
                                                          icon: const Icon(Icons.payment_rounded, size: 14),
                                                          label: const Text(
                                                            'Pay UPI',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                          ),
                                                          style: OutlinedButton.styleFrom(
                                                            foregroundColor: AppColors.primary,
                                                            side: BorderSide(color: AppColors.primary),
                                                            shape: RoundedRectangleBorder(
                                                              borderRadius: BorderRadius.circular(8),
                                                            ),
                                                            padding: const EdgeInsets.symmetric(vertical: 6),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: ElevatedButton.icon(
                                                          onPressed: settling
                                                              ? null
                                                              : () {
                                                                  final expIds = data.unsettledExpenses
                                                                      .where((e) => e.userId == tx.toUserId)
                                                                      .map((e) => e.id)
                                                                      .toList();
                                                                  _performSettlement(tx, expIds);
                                                                },
                                                          icon: const Icon(Icons.check_rounded, size: 14),
                                                          label: const Text(
                                                            'Settle',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                          ),
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor: const Color(0xFF10B981),
                                                            foregroundColor: Colors.white,
                                                            shape: RoundedRectangleBorder(
                                                              borderRadius: BorderRadius.circular(8),
                                                            ),
                                                            padding: const EdgeInsets.symmetric(vertical: 6),
                                                            elevation: 0,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    const SizedBox(height: AppSpacing.lg),
                                    
                                    // Big Pay and Settle Button
                                    if (data.unsettledExpensesCount > 0)
                                      ElevatedButton(
                                        onPressed: () {
                                          context.push(
                                            '/bill-selection',
                                            extra: {
                                              'groupId': selectedGroupId,
                                              'expenses': data.unsettledExpenses,
                                            },
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.white,
                                          minimumSize: const Size.fromHeight(54),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                        child: const Text(
                                          'Pay and Settle Bills',
                                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    const SizedBox(height: 100),
                                  ],
                                );
                              },
                            ),
                      ),
                    ),
              ),
            ],
          );
        },
      ),
    );
  }
}
