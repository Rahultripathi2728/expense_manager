import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:expense_manager/app/theme/theme_provider.dart';
import 'package:appwrite/appwrite.dart';
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

class _SettlementPageState extends ConsumerState<SettlementPage> {
  String? selectedGroupId;
  bool settling = false;
  bool _initialGroupSet = false;

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
            Center(child: CircularProgressIndicator(color: AppColors.textPrimary)),
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
                    : SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: ref
                            .watch(groupBalancesProvider(selectedGroupId!))
                            .when(
                              loading: () => Padding(
                                padding: const EdgeInsets.only(top: 40),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
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
                                                            // Show confirmation dialog
                                                            final confirmed = await showDialog<bool>(
                                                              context: context,
                                                              builder: (ctx) => AlertDialog(
                                                                shape: RoundedRectangleBorder(
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        16,
                                                                      ),
                                                                ),
                                                                title: const Text(
                                                                  'Confirm Settlement',
                                                                  style: TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                  ),
                                                                ),
                                                                content: Text(
                                                                  '${data.profiles[tx.fromUserId]?.fullName ?? "User"} pays ${data.profiles[tx.toUserId]?.fullName ?? "User"} ${DateHelpers.formatCurrency(tx.amount)}.\n\nThis will mark all related expenses as settled. This action cannot be undone.',
                                                                ),
                                                                actions: [
                                                                  TextButton(
                                                                    onPressed: () =>
                                                                        Navigator.pop(
                                                                          ctx,
                                                                          false,
                                                                        ),
                                                                    child: const Text(
                                                                      'Cancel',
                                                                      style: TextStyle(
                                                                        color: Colors
                                                                            .grey,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  ElevatedButton(
                                                                    style: ElevatedButton.styleFrom(
                                                                      backgroundColor:
                                                                          Colors
                                                                              .black,
                                                                      foregroundColor:
                                                                          Colors
                                                                              .white,
                                                                      minimumSize: const Size(100, 48),
                                                                      shape: RoundedRectangleBorder(
                                                                        borderRadius:
                                                                            BorderRadius.circular(
                                                                              8,
                                                                            ),
                                                                      ),
                                                                    ),
                                                                    onPressed: () =>
                                                                        Navigator.pop(
                                                                          ctx,
                                                                          true,
                                                                        ),
                                                                    child: const Text(
                                                                      'Settle',
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            );
                                                            if (confirmed !=
                                                                true) {
                                                              return;
                                                            }

                                                            setState(
                                                              () => settling =
                                                                  true,
                                                            );
                                                            try {
                                                              final repo = ref.read(
                                                                settlementRepositoryProvider,
                                                              );
                                                              final expIds = data
                                                                  .unsettledExpenses
                                                                  .map(
                                                                    (e) => e.id,
                                                                  )
                                                                  .toList();

                                                              // Attempt to settle using backend, or local fallback
                                                              try {
                                                                await repo.settleBalances(
                                                                  selectedGroupId!,
                                                                  tx.fromUserId,
                                                                  tx.toUserId,
                                                                  tx.amount,
                                                                );
                                                              } catch (_) {
                                                                // Fallback client-side update
                                                                await repo.settleBalancesLocalFallback(
                                                                  selectedGroupId!,
                                                                  tx.fromUserId,
                                                                  tx.toUserId,
                                                                  tx.amount,
                                                                  expIds,
                                                                );
                                                              }

                                                              ref.invalidate(
                                                                groupBalancesProvider(
                                                                  selectedGroupId!,
                                                                ),
                                                              );
                                                              ref.invalidate(
                                                                monthlyExpensesProvider,
                                                              );

                                                              if (context
                                                                  .mounted) {
                                                                ScaffoldMessenger.of(
                                                                  context,
                                                                ).showSnackBar(
                                                                  const SnackBar(
                                                                    content: Text(
                                                                      'Balances Settled!',
                                                                    ),
                                                                    backgroundColor:
                                                                        Colors
                                                                            .green,
                                                                  ),
                                                                );
                                                              }
                                                            } catch (e) {
                                                              if (context
                                                                  .mounted) {
                                                                ScaffoldMessenger.of(
                                                                  context,
                                                                ).showSnackBar(
                                                                  SnackBar(
                                                                    content: Text(
                                                                      'Settlement failed: $e',
                                                                    ),
                                                                    backgroundColor:
                                                                        Colors
                                                                            .red,
                                                                  ),
                                                                );
                                                              }
                                                            } finally {
                                                              if (mounted) {
                                                                setState(
                                                                  () =>
                                                                      settling =
                                                                          false,
                                                                );
                                                              }
                                                            }
                                                          },
                                                    child: const Text(
                                                      'Mark as Settled',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
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
            ],
          );
        },
      ),
    );
  }
}
