import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:expense_manager/app/theme/theme_provider.dart';
import 'package:appwrite/appwrite.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../core/utils/haptic_helper.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/constants/app_constants.dart';
import '../../../core/appwrite_client.dart';
import '../../../core/utils/date_helpers.dart';
import '../../../core/utils/row_helpers.dart';
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

final groupBalancesProvider = FutureProvider.family<GroupBalanceData, String>((
  ref,
  groupId,
) async {
  final repo = ref.watch(expenseRepositoryProvider);

  // 1. Fetch group members
  final members = await ref
      .read(groupRepositoryProvider)
      .getGroupMembers(groupId);
  final userIds = members.map((m) => m.userId).toList();

  if (userIds.isEmpty) {
    return GroupBalanceData(
      membersCount: 0,
      unsettledExpensesCount: 0,
      totalUnsettledAmount: 0,
      netBalances: {},
      paidAmounts: {},
      shareAmounts: {},
      transactions: [],
      profiles: {},
      unsettledExpenses: [],
    );
  }

  // Fetch profiles for names
  final tablesDB = ref.watch(appwriteTablesDBProvider);
  final resProfiles = await tablesDB.listRows(
    databaseId: AppConstants.databaseId,
    tableId: AppConstants.profilesCollection,
    queries: [Query.equal('userId', userIds)],
  );
  final profiles = resProfiles.rows
      .map((d) => Profile.fromMap(d.dataWithId))
      .toList();
  final profileMap = {for (var p in profiles) p.userId: p};

  // 2. Fetch group expenses
  final allExpenses = await repo.getGroupExpenses(groupId);
  final unsettledExpenses = allExpenses.where((e) => !e.isSettled).toList();

  // 3. Fetch splits for unsettled expenses
  final List<ExpenseSplit> allSplits = [];
  for (final exp in unsettledExpenses) {
    try {
      final splits = await repo.getExpenseSplits(exp.id);
      allSplits.addAll(splits);
    } catch (_) {}
  }

  // 4. Calculate net balances
  final netBalances = BalanceCalculator.calculateNetBalances(
    expenses: unsettledExpenses,
    allSplits: allSplits,
  );

  // Paid and share maps
  final Map<String, double> paidMap = {for (var id in userIds) id: 0.0};
  final Map<String, double> shareMap = {for (var id in userIds) id: 0.0};

  for (final exp in unsettledExpenses) {
    paidMap[exp.userId] = (paidMap[exp.userId] ?? 0.0) + exp.amount;
    final expSplits = allSplits.where((s) => s.expenseId == exp.id).toList();
    for (final s in expSplits) {
      if (s.isIncluded) {
        shareMap[s.userId] = (shareMap[s.userId] ?? 0.0) + s.amountOwed;
      }
    }
  }

  // Simplify transactions
  final transactions = BalanceCalculator.simplifyTransactions(netBalances);

  // Fetch last settlement
  final settlementsRepo = ref.watch(settlementRepositoryProvider);
  final settlements = await settlementsRepo.getGroupSettlements(groupId);
  final Settlement? lastSettlement = settlements.isNotEmpty
      ? settlements.first
      : null;

  return GroupBalanceData(
    membersCount: userIds.length,
    unsettledExpensesCount: unsettledExpenses.length,
    totalUnsettledAmount: unsettledExpenses.fold<double>(
      0.0,
      (sum, e) => sum + e.amount,
    ),
    netBalances: netBalances,
    paidAmounts: paidMap,
    shareAmounts: shareMap,
    transactions: transactions,
    profiles: profileMap,
    lastSettlement: lastSettlement,
    unsettledExpenses: unsettledExpenses,
  );
});

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
  });
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

  Future<void> _performSettlement(SimplifiedTransaction tx, List<String> expIds) async {
    setState(() => settling = true);
    try {
      final repo = ref.read(settlementRepositoryProvider);
      try {
        await repo.settleBalances(
          selectedGroupId!,
          tx.fromUserId,
          tx.toUserId,
          tx.amount,
        );
      } catch (_) {
        await repo.settleBalancesLocalFallback(
          selectedGroupId!,
          tx.fromUserId,
          tx.toUserId,
          tx.amount,
          expIds,
        );
      }

      ref.invalidate(groupBalancesProvider(selectedGroupId!));
      ref.invalidate(monthlyExpensesProvider);

      if (mounted) {
        HapticHelper.mediumTap();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Balances Settled!'),
            backgroundColor: Colors.green,
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

  void _showNoUpiIdBottomSheet(SimplifiedTransaction tx, List<String> expIds, String toName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.warningMuted,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.warning,
                        size: AppSpacing.iconXl,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        'UPI ID Not Found',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  '$toName has not added their UPI ID to their profile. You cannot initiate an automatic UPI payment redirect.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'If you have paid them via cash or another app, you can manually mark this settlement as complete.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.textPrimary,
                    foregroundColor: AppColors.surface,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _performSettlement(tx, expIds);
                  },
                  child: const Text(
                    'Mark as Settled (Manual)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
              onPressed: () {
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

  void _showFallbackManualSettlement(SimplifiedTransaction tx, {required String errorMsg}) {
    final toName = ref.read(groupBalancesProvider(selectedGroupId!)).valueOrNull?.profiles[tx.toUserId]?.fullName ?? 'User';
    final expIds = _pendingExpIds ?? [];

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          ),
          title: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: AppColors.warning,
                size: AppSpacing.iconLg,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'UPI Redirect Failed',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            '$errorMsg\n\nWould you like to manually mark this settlement of ${DateHelpers.formatCurrency(tx.amount)} to $toName as complete?',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _pendingTransaction = null;
                _pendingExpIds = null;
                Navigator.pop(ctx);
              },
              child: Text(
                'Cancel',
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
              onPressed: () {
                _pendingTransaction = null;
                _pendingExpIds = null;
                Navigator.pop(ctx);
                _performSettlement(tx, expIds);
              },
              child: const Text(
                'Mark as Settled',
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
                                        ? AppColors.textPrimary
                                        : AppColors.borderLight,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 24,
                                  backgroundColor: isSelected
                                      ? AppColors.textPrimary
                                      : AppColors.surface,
                                  child: Text(
                                    initials,
                                    style: TextStyle(
                                      color: isSelected
                                          ? AppColors.surface
                                          : AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
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
                                                '${data.membersCount} members • ${data.unsettledExpensesCount} expenses since last settlement',
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

                                    // Who Spent How Much Header
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.wallet,
                                          size: 20,
                                          color: AppColors.textPrimary,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Who Spent How Much',
                                          style: TextStyle(
                                            fontSize: 20,
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
                                              color: AppColors.borderLight,
                                            ),
                                          ),
                                          child: ExpansionTile(
                                            leading: CircleAvatar(
                                              backgroundColor: const Color(
                                                0xFFF3F3F3,
                                              ),
                                              child: Text(
                                                p.fullName
                                                    .substring(0, 1)
                                                    .toUpperCase(),
                                                style: TextStyle(
                                                  color: AppColors.textPrimary,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            title: Text(
                                              isMe
                                                  ? '${p.fullName} (You)'
                                                  : p.fullName,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            subtitle: Text(
                                              'Paid ${DateHelpers.formatCurrency(paid)} • Share ${DateHelpers.formatCurrency(share)}',
                                              style: TextStyle(
                                                color: AppColors.textSecondary,
                                                fontSize: 12,
                                              ),
                                            ),
                                            trailing: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (net.abs() < 0.05)
                                                  const Text(
                                                    'Settled',
                                                    style: TextStyle(
                                                      color: Color(0xFF22C55E),
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 13,
                                                    ),
                                                  )
                                                else if (net > 0)
                                                  Text(
                                                    'Gets back ${DateHelpers.formatCurrency(net)}',
                                                    style: const TextStyle(
                                                      color: Color(0xFF22C55E),
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 13,
                                                    ),
                                                  )
                                                else
                                                  Text(
                                                    'Owes ${DateHelpers.formatCurrency(-net)}',
                                                    style: TextStyle(
                                                      color: AppColors.error,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                Icon(
                                                  Icons.keyboard_arrow_down,
                                                  color: AppColors.textSecondary,
                                                  size: 18,
                                                ),
                                              ],
                                            ),
                                            children: [
                                              Padding(
                                                padding: const EdgeInsets.all(
                                                  16,
                                                ),
                                                child: Text(
                                                  'Details: total paid: ${DateHelpers.formatCurrency(paid)} towards unsettled expenses. Total share calculated: ${DateHelpers.formatCurrency(share)}.',
                                                  style: TextStyle(
                                                    color: AppColors.textSecondary,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                            ],
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
                                                color: AppColors.borderLight,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.arrow_forward,
                                                  color: AppColors.textSecondary,
                                                  size: 16,
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
                                                              const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: Colors
                                                                    .black,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                if (tx.fromUserId == myUserId)
                                                  ElevatedButton(
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor:
                                                          AppColors.textPrimary,
                                                      foregroundColor:
                                                          AppColors.surface,
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 12,
                                                            vertical: 6,
                                                          ),
                                                      minimumSize: Size.zero,
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                      ),
                                                    ),
                                                    onPressed: settling
                                                        ? null
                                                        : () async {
                                                            final payeeProfile = data.profiles[tx.toUserId];
                                                            final payeeUpiId = payeeProfile?.upiId;
                                                            final expIds = data.unsettledExpenses.map((e) => e.id).toList();

                                                            if (payeeUpiId == null || payeeUpiId.trim().isEmpty) {
                                                              _showNoUpiIdBottomSheet(tx, expIds, toName);
                                                            } else {
                                                              final groupName = groups.firstWhere(
                                                                (g) => g.id == selectedGroupId,
                                                                orElse: () => groups.first,
                                                              ).name;

                                                              final upiUri = Uri.parse(
                                                                'upi://pay?pa=$payeeUpiId'
                                                                '&pn=${Uri.encodeComponent(payeeProfile?.fullName ?? 'User')}'
                                                                '&am=${tx.amount.toStringAsFixed(2)}'
                                                                '&cu=INR'
                                                                '&tn=${Uri.encodeComponent("Settle Bill $groupName")}'
                                                              );

                                                              _pendingTransaction = tx;
                                                              _pendingExpIds = expIds;

                                                              try {
                                                                if (await canLaunchUrl(upiUri)) {
                                                                  await launchUrl(
                                                                    upiUri,
                                                                    mode: LaunchMode.externalApplication,
                                                                  );
                                                                  if (kIsWeb && mounted) {
                                                                    _showResumptionConfirmationDialog(tx);
                                                                  }
                                                                } else {
                                                                  if (mounted) {
                                                                    _showFallbackManualSettlement(
                                                                      tx,
                                                                      errorMsg: 'No UPI applications were found on this device or UPI scheme is not supported.',
                                                                    );
                                                                  }
                                                                }
                                                              } catch (e) {
                                                                if (mounted) {
                                                                  _showFallbackManualSettlement(
                                                                    tx,
                                                                    errorMsg: 'Could not redirect to UPI app: $e',
                                                                  );
                                                                }
                                                              }
                                                            }
                                                          },
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          Icons.bolt,
                                                          size: 14,
                                                          color: AppColors.surface,
                                                        ),
                                                        const SizedBox(width: 4),
                                                        const Text(
                                                          'Pay & Settle',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          );
                                        },
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
