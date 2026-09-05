import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:expense_manager/app/theme/theme_provider.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/constants/app_constants.dart';
import '../../../core/appwrite_client.dart';
import '../../../core/utils/date_helpers.dart';
import '../../../core/utils/row_helpers.dart';
import '../../expenses/presentation/add_expense/add_expense_screen.dart';
import '../../expenses/presentation/utils/category_icon_helper.dart';
import '../../expenses/domain/expense_model.dart';
import '../domain/group_model.dart';
import '../domain/group_member_model.dart';
import '../../../shared/widgets/skeleton_loading_card.dart';
import '../../../shared/widgets/custom_error_widget.dart';
import '../data/group_repository.dart';
import '../../auth/data/auth_repository.dart';
import '../../expenses/data/expense_repository.dart';
import '../../settlement/presentation/settlement_page.dart';
import '../../profile/domain/profile_model.dart';
import '../../calendar/presentation/widgets/calendar_expense_card.dart'; // For expenseSplitsProvider

final groupDetailProvider = FutureProvider.family<Group?, String>((
  ref,
  groupId,
) async {
  final tablesDB = ref.watch(appwriteTablesDBProvider);
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

final groupMembersListProvider =
    FutureProvider.family<List<GroupMember>, String>((ref, groupId) async {
      return ref.watch(groupRepositoryProvider).getGroupMembers(groupId);
    });

final groupAllExpensesProvider =
    FutureProvider.family<List<Expense>, String>((ref, groupId) async {
  return ref.watch(expenseRepositoryProvider).getGroupExpenses(groupId);
});

class GroupDetailPage extends ConsumerStatefulWidget {
  final String groupId;
  const GroupDetailPage({super.key, required this.groupId});

  @override
  ConsumerState<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends ConsumerState<GroupDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedExpenseMonth = DateTime.now();
  String _statusFilter = 'all'; // 'all', 'settled', 'unsettled'
  DateTimeRange? _customDateRange;
  String? _selectedCategoryFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    final groupAsync = ref.watch(groupDetailProvider(widget.groupId));
    final profilesAsync = ref.watch(groupProfilesProvider(widget.groupId));
    final membersAsync = ref.watch(groupMembersListProvider(widget.groupId));
    final balancesAsync = ref.watch(groupBalancesProvider(widget.groupId));
    final currentUser = ref.watch(authStateProvider).valueOrNull;

    return groupAsync.when(
      loading: () => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          title: const Text('Group Details'),
        ),
        body: const Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: SkeletonGroupList(itemCount: 1),
        ),
      ),
      error: (err, _) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          title: const Text('Group Details'),
        ),
        body: Center(
          child: Text('Error loading group: $err', style: const TextStyle(color: Colors.red)),
        ),
      ),
      data: (group) {
        if (group == null) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(backgroundColor: AppColors.surface),
            body: const Center(child: Text('Group not found')),
          );
        }

        final gradients = [
          [const Color(0xFF2481E9), const Color(0xFF00C6FF)],
          [const Color(0xFF8B5CF6), const Color(0xFFC084FC)],
          [const Color(0xFFEC4899), const Color(0xFFF472B6)],
          [const Color(0xFF10B981), const Color(0xFF34D399)],
          [const Color(0xFFF59E0B), const Color(0xFFFBBF24)],
        ];
        final grad = gradients[group.name.hashCode.abs() % gradients.length];

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
              onPressed: () => context.pop(),
            ),
            title: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: grad,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      group.name.isNotEmpty ? group.name[0].toUpperCase() : 'G',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    group.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Icon(
                    Icons.history_rounded,
                    size: 20,
                    color: AppColors.textPrimary,
                  ),
                ),
                tooltip: 'Settlement History',
                onPressed: () {
                  context.push('/settlement-history', extra: group.id);
                },
              ),
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Icon(
                    Icons.settings_outlined,
                    size: 20,
                    color: AppColors.textPrimary,
                  ),
                ),
                tooltip: 'Group Settings & Members',
                onPressed: () {
                  _showGroupSettingsSheet(
                    context,
                    ref,
                    group,
                    membersAsync.valueOrNull ?? [],
                    profilesAsync.valueOrNull ?? [],
                    currentUser?.id ?? '',
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.borderLight)),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 3,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  tabs: const [
                    Tab(text: 'Balances & Settle'),
                    Tab(text: 'Group Expenses'),
                  ],
                ),
              ),
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              // Tab 1: Balances & Settlement Dashboard
              Column(
                children: [
                  Expanded(child: _buildBalancesTab(balancesAsync, group, currentUser)),
                  _buildBottomSettlementBar(balancesAsync, group, currentUser) ?? const SizedBox.shrink(),
                ],
              ),

              // Tab 2: Group Expenses List (With Month Navigation & Filters)
              _buildExpensesTab(group, profilesAsync.valueOrNull ?? []),
            ],
          ),
        );
      },
    );
  }

  Widget? _buildBottomSettlementBar(
    AsyncValue<GroupBalanceData> balancesAsync,
    Group group,
    dynamic currentUser,
  ) {
    final data = balancesAsync.valueOrNull;
    if (data == null) return null;

    final myUserId = currentUser?.id ?? '';
    final myNet = data.netBalances[myUserId] ?? 0.0;
    final owesMoney = myNet < -0.01;
    final isOwedMoney = myNet > 0.01;
    final hasUnsettled = data.unsettledExpenses.isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.borderLight)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: owesMoney
            ? ElevatedButton.icon(
                onPressed: () {
                  context.push(
                    '/payment-summary',
                    extra: {
                      'groupId': group.id,
                      'expenses': data.unsettledExpenses,
                    },
                  );
                },
                icon: const Icon(Icons.payment_rounded, color: Colors.white, size: 20),
                label: Text(
                  'Pay & Settle Up (${DateHelpers.formatCurrency(myNet.abs())})',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 2,
                ),
              )
            : isOwedMoney
                ? Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.hourglass_top_rounded, color: Color(0xFF10B981), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'You are owed ${DateHelpers.formatCurrency(myNet)} • Awaiting Payments',
                          style: const TextStyle(
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline_rounded, color: AppColors.textSecondary, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          hasUnsettled ? 'Your Share is Settled ✅' : 'All Settled Up 🎉',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildBalancesTab(
    AsyncValue<GroupBalanceData> balancesAsync,
    Group group,
    dynamic currentUser,
  ) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        ref.invalidate(groupBalancesProvider(group.id));
      },
      child: balancesAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: SkeletonList(itemCount: 4),
        ),
        error: (err, _) => CustomErrorWidget(
          error: err,
          onRetry: () => ref.refresh(groupBalancesProvider(group.id)),
        ),
        data: (data) {
          final myUserId = currentUser?.id ?? '';
          final myNet = data.netBalances[myUserId] ?? 0.0;

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Balance Summary Hero Card (Top)
                _buildHeroBalanceCard(myNet, data, group),
                const SizedBox(height: 20),

                // 2. Member Balances Breakdown (Second)
                Text(
                  'Member Balances',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),

                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: data.profiles.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final p = data.profiles.values.elementAt(index);
                    final isMe = p.userId == myUserId;
                    final net = data.netBalances[p.userId] ?? 0.0;
                    final paid = data.paidAmounts[p.userId] ?? 0.0;
                    final share = data.shareAmounts[p.userId] ?? 0.0;
                    final paidExps = data.getPaidExpenses(p.userId);
                    final sharedExps = data.getSharedExpenses(p.userId);

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
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isMe
                              ? AppColors.primary.withValues(alpha: 0.35)
                              : AppColors.borderLight,
                          width: isMe ? 1.5 : 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        clipBehavior: Clip.antiAlias,
                        child: Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                            leading: Container(
                              width: 42,
                              height: 42,
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
                                  p.fullName.isNotEmpty ? p.fullName[0].toUpperCase() : 'U',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                            title: Text(
                              isMe ? '${p.fullName} (You)' : p.fullName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14.5,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                'Paid ${DateHelpers.formatCurrency(paid)} • Share ${DateHelpers.formatCurrency(share)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
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
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Total Bills Paid:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                        Text(
                                          DateHelpers.formatCurrency(paid),
                                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Total Share (Consumed):', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                        Text(
                                          DateHelpers.formatCurrency(share),
                                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.error),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Net Balance (${paid.toStringAsFixed(0)} - ${share.toStringAsFixed(0)}):',
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                        ),
                                        Text(
                                          badgeText,
                                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: badgeColor),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),

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
                                    '${p.fullName.split(' ').first}''s Share in Bills (${sharedExps.length})',
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
                const SizedBox(height: 20),

                // 3. Suggested Settlements (Who pays whom to settle all debts)
                _buildSuggestedSettlementsCard(data, myUserId),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSuggestedSettlementsCard(GroupBalanceData data, String myUserId) {
    if (data.transactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'No pending transfers! All member shares are balanced.',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Suggested Settlements',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${data.transactions.length} ${data.transactions.length == 1 ? 'transfer' : 'transfers'}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: data.transactions.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final tx = data.transactions[index];
            final fromProfile = data.profiles[tx.fromUserId];
            final toProfile = data.profiles[tx.toUserId];
            final fromName = fromProfile?.fullName ?? 'Member';
            final toName = toProfile?.fullName ?? 'Member';
            final isMyDebt = tx.fromUserId == myUserId;
            final isOwedToMe = tx.toUserId == myUserId;

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isMyDebt
                    ? const Color(0xFFEF4444).withValues(alpha: 0.05)
                    : isOwedToMe
                        ? const Color(0xFF10B981).withValues(alpha: 0.05)
                        : AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isMyDebt
                      ? const Color(0xFFEF4444).withValues(alpha: 0.3)
                      : isOwedToMe
                          ? const Color(0xFF10B981).withValues(alpha: 0.3)
                          : AppColors.borderLight,
                ),
              ),
              child: Row(
                children: [
                  // From User Avatar
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isMyDebt ? const Color(0xFFEF4444) : AppColors.surfaceVariant,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        fromName.isNotEmpty ? fromName[0].toUpperCase() : 'U',
                        style: TextStyle(
                          color: isMyDebt ? Colors.white : AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Names & Transfer Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                isMyDebt ? 'You' : fromName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: isMyDebt ? const Color(0xFFEF4444) : AppColors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.textTertiary),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                isOwedToMe ? 'You' : toName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: isOwedToMe ? const Color(0xFF10B981) : AppColors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isMyDebt
                              ? 'You need to pay $toName'
                              : isOwedToMe
                                  ? '$fromName will pay you'
                                  : 'Direct transfer',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Amount Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isMyDebt
                          ? const Color(0xFFEF4444).withValues(alpha: 0.12)
                          : isOwedToMe
                              ? const Color(0xFF10B981).withValues(alpha: 0.12)
                              : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      DateHelpers.formatCurrency(tx.amount),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: isMyDebt
                            ? const Color(0xFFEF4444)
                            : isOwedToMe
                                ? const Color(0xFF10B981)
                                : AppColors.textPrimary,
                      ),
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

  Widget _buildHeroBalanceCard(double myNet, GroupBalanceData data, Group group) {
    final bool isOwed = myNet > 0.01;
    final bool owes = myNet < -0.01;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isOwed
              ? [const Color(0xFF10B981), const Color(0xFF059669)]
              : owes
              ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
              : [AppColors.primary, const Color(0xFF1D4ED8)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: (isOwed
                    ? const Color(0xFF10B981)
                    : owes
                    ? const Color(0xFFEF4444)
                    : AppColors.primary)
                .withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isOwed
                    ? 'YOU ARE OWED'
                    : owes
                    ? 'YOU OWE'
                    : 'ALL SETTLED UP',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${data.membersCount} Members',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '₹${myNet.abs().toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            data.unsettledExpensesCount > 0
                ? '${data.unsettledExpensesCount} unsettled ${data.unsettledExpensesCount == 1 ? 'expense' : 'expenses'} total (₹${data.totalUnsettledAmount.toStringAsFixed(0)})'
                : 'All expenses settled up',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 12,
              fontWeight: data.unsettledExpensesCount == 0 ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpensesTab(Group group, List<Profile> profiles) {
    final currentUser = ref.watch(authStateProvider).valueOrNull;
    final allExpensesAsync = ref.watch(groupAllExpensesProvider(group.id));
    final balancesAsync = ref.watch(groupBalancesProvider(group.id));
    final userSplits = ref.watch(userSplitsProvider).valueOrNull ?? [];
    final myExpenseIds = userSplits
        .where((s) => s.amountOwed > 0)
        .map((s) => s.expenseId)
        .toSet();
    final profileMap = {for (var p in profiles) p.userId: p};
    final hasActiveFilter = _statusFilter != 'all' || _customDateRange != null || _selectedCategoryFilter != null;

    return Column(
      children: [
        // Month Selector & Filter Bar
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderLight),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Previous Month Arrow (Left)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _customDateRange = null;
                      _selectedExpenseMonth = DateTime(
                        _selectedExpenseMonth.year,
                        _selectedExpenseMonth.month - 1,
                      );
                    });
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.chevron_left_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Month / Date Range Display
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _pickCustomMonth(context),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.calendar_month_rounded, size: 16, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _customDateRange != null
                                  ? '${DateHelpers.formatDayMonth(_customDateRange!.start)} - ${DateHelpers.formatDayMonth(_customDateRange!.end)}'
                                  : DateHelpers.formatMonthYear(_selectedExpenseMonth),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Next Month Arrow (Right)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _customDateRange = null;
                      _selectedExpenseMonth = DateTime(
                        _selectedExpenseMonth.year,
                        _selectedExpenseMonth.month + 1,
                      );
                    });
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Filter Button (Far Right)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showFilterBottomSheet(context),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: hasActiveFilter
                          ? AppColors.primary
                          : AppColors.surfaceVariant.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: hasActiveFilter ? AppColors.primary : AppColors.borderLight,
                      ),
                    ),
                    child: Icon(
                      Icons.tune_rounded,
                      size: 18,
                      color: hasActiveFilter ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Expense List
        Expanded(
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              ref.invalidate(groupAllExpensesProvider(group.id));
              ref.invalidate(groupBalancesProvider(group.id));
            },
            child: allExpensesAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: SkeletonList(itemCount: 4),
              ),
              error: (err, _) => Center(child: Text('Error loading expenses: $err')),
              data: (expenses) {
                // Apply Month / Date Filter
                final filtered = expenses.where((exp) {
                  // Date Filter
                  if (_customDateRange != null) {
                    if (exp.expenseDate.isBefore(_customDateRange!.start) ||
                        exp.expenseDate.isAfter(_customDateRange!.end.add(const Duration(days: 1)))) {
                      return false;
                    }
                  } else {
                    if (exp.expenseDate.year != _selectedExpenseMonth.year ||
                        exp.expenseDate.month != _selectedExpenseMonth.month) {
                      return false;
                    }
                  }

                  // Status Filter
                  bool isExpSettled = exp.isSettled;
                  final balancesData = balancesAsync.valueOrNull;
                  if (!isExpSettled && balancesData != null) {
                    if (balancesData.unsettledExpenses.any((u) => u.id == exp.id)) {
                      isExpSettled = false;
                    } else if (balancesData.lastSettlement != null &&
                        (exp.createdAt.isBefore(balancesData.lastSettlement!.createdAt) ||
                            exp.createdAt.isAtSameMomentAs(balancesData.lastSettlement!.createdAt))) {
                      isExpSettled = true;
                    }
                  }
                  if (_statusFilter == 'settled' && !isExpSettled) return false;
                  if (_statusFilter == 'unsettled' && isExpSettled) return false;

                  // Category Filter
                  if (_selectedCategoryFilter != null &&
                      exp.category.toLowerCase() != _selectedCategoryFilter!.toLowerCase()) {
                    return false;
                  }

                  // Involvement Filter: Hide if user is not creator and owes nothing
                  if (currentUser != null && exp.userId != currentUser.id && !myExpenseIds.contains(exp.id)) {
                    return false;
                  }

                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 56, color: AppColors.textTertiary),
                          const SizedBox(height: 12),
                          Text(
                            'No Expenses Found',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            hasActiveFilter
                                ? 'Try clearing or changing your filters'
                                : 'No expenses recorded for ${DateHelpers.formatMonthYear(_selectedExpenseMonth)}',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                          if (hasActiveFilter) ...[
                            const SizedBox(height: 16),
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _statusFilter = 'all';
                                  _customDateRange = null;
                                  _selectedCategoryFilter = null;
                                });
                              },
                              icon: const Icon(Icons.clear_rounded, size: 16),
                              label: const Text('Clear Filters'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }

                final totalAmount = filtered.fold<double>(0.0, (sum, e) => sum + e.amount);

                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                  children: [
                    // Summary sub-header
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${filtered.length} ${filtered.length == 1 ? 'Expense' : 'Expenses'}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            'Total: ₹${totalAmount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    ...filtered.map((exp) {
                      final payer = profileMap[exp.userId];

                      return Consumer(
                        builder: (context, ref, child) {
                          final splitsAsync = ref.watch(expenseSplitsProvider(exp.id));
                          return splitsAsync.when(
                            data: (splits) {
                              if (currentUser != null && exp.userId != currentUser.id) {
                                final mySplit = splits.where((s) => s.userId == currentUser.id).firstOrNull;
                                if (mySplit == null || !mySplit.isIncluded || mySplit.amountOwed < 0.01) {
                                  return const SizedBox.shrink();
                                }
                              }

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.borderLight),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.02),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: InkWell(
                                  onTap: () {
                                    context.push('/expense-detail', extra: exp);
                                  },
                                  child: Row(
                                    children: [
                                      CategoryIconHelper.buildBadge(exp.category, size: 40, iconSize: 20),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              exp.description.isNotEmpty ? exp.description : exp.category,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Row(
                                              children: [
                                                Text(
                                                  'Paid by ${payer?.fullName ?? 'Member'} • ${DateHelpers.formatDayMonth(exp.expenseDate)}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: AppColors.textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '₹${exp.amount.toStringAsFixed(0)}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          Builder(builder: (context) {
                                            bool isExpSettled = exp.isSettled;
                                            final balancesData = balancesAsync.valueOrNull;
                                            if (!isExpSettled && balancesData != null) {
                                              if (balancesData.unsettledExpenses.any((u) => u.id == exp.id)) {
                                                isExpSettled = false;
                                              } else if (balancesData.lastSettlement != null &&
                                                  (exp.createdAt.isBefore(balancesData.lastSettlement!.createdAt) ||
                                                      exp.createdAt.isAtSameMomentAs(balancesData.lastSettlement!.createdAt))) {
                                                isExpSettled = true;
                                              }
                                            }
                                            return Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isExpSettled
                                                    ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                                    : const Color(0xFFF59E0B).withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                isExpSettled ? 'Settled' : 'Unsettled',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: isExpSettled
                                                      ? const Color(0xFF10B981)
                                                      : const Color(0xFFF59E0B),
                                                ),
                                              ),
                                            );
                                          }),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                          );
                        }
                      );
                    }),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  void _pickCustomMonth(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedExpenseMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) {
      setState(() {
        _selectedExpenseMonth = DateTime(picked.year, picked.month);
        _customDateRange = null;
      });
    }
  }

  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filter Group Expenses',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _statusFilter = 'all';
                            _customDateRange = null;
                            _selectedCategoryFilter = null;
                          });
                          Navigator.pop(ctx);
                        },
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Status Filter
                  Text(
                    'Bill Status',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildFilterToggle('all', 'All Bills', setModalState),
                      const SizedBox(width: 8),
                      _buildFilterToggle('unsettled', 'Unsettled', setModalState),
                      const SizedBox(width: 8),
                      _buildFilterToggle('settled', 'Settled', setModalState),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Custom Date Range
                  Text(
                    'Date Range',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: AppColors.borderLight),
                    ),
                    leading: Icon(Icons.date_range_rounded, color: AppColors.primary),
                    title: Text(
                      _customDateRange != null
                          ? '${DateHelpers.formatDayMonth(_customDateRange!.start)} - ${DateHelpers.formatDayMonth(_customDateRange!.end)}'
                          : 'Select Custom Date Range',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: _customDateRange != null ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    trailing: _customDateRange != null
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              setModalState(() => _customDateRange = null);
                              setState(() => _customDateRange = null);
                            },
                          )
                        : const Icon(Icons.chevron_right_rounded),
                    onTap: () async {
                      final range = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                        initialDateRange: _customDateRange ??
                            DateTimeRange(
                              start: DateTime(_selectedExpenseMonth.year, _selectedExpenseMonth.month, 1),
                              end: DateTime(_selectedExpenseMonth.year, _selectedExpenseMonth.month + 1, 0),
                            ),
                      );
                      if (range != null) {
                        setModalState(() => _customDateRange = range);
                        setState(() => _customDateRange = range);
                      }
                    },
                  ),
                  const SizedBox(height: 24),

                  // Apply Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Apply Filters', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterToggle(String key, String label, StateSetter setModalState) {
    final isSelected = _statusFilter == key;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setModalState(() => _statusFilter = key);
          setState(() => _statusFilter = key);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  void _showGroupSettingsSheet(
    BuildContext context,
    WidgetRef ref,
    Group group,
    List<GroupMember> members,
    List<Profile> profiles,
    String myUserId,
  ) {
    final myMember = members.where((m) => m.userId == myUserId).firstOrNull;
    final isAdmin = myMember?.isAdmin ?? false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: ListView(
                controller: scrollController,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Group Settings',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Join Code Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.vpn_key_rounded, color: AppColors.primary, size: 22),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Group Join Code',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            Text(
                              group.joinCode,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: group.joinCode));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Join code "${group.joinCode}" copied!', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                backgroundColor: const Color(0xFF1E293B),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy_rounded, size: 14),
                          label: const Text('Copy'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 36),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Members Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Group Members (${profiles.length})',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Member List
                  ...profiles.map((prof) {
                    final member = members.where((m) => m.userId == prof.userId).firstOrNull;
                    final isMemberAdmin = member?.isAdmin ?? false;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
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
                            ),
                            child: Center(
                              child: Text(
                                prof.fullName.isNotEmpty ? prof.fullName[0].toUpperCase() : 'U',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  prof.userId == myUserId ? '${prof.fullName} (You)' : prof.fullName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                Text(
                                  isMemberAdmin ? 'Admin' : 'Member',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isMemberAdmin ? AppColors.primary : AppColors.textTertiary,
                                    fontWeight: isMemberAdmin ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 24),

                  // Leave / Delete Actions
                  if (isAdmin) ...[
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _handleDeleteGroup(context, ref, group);
                      },
                      icon: Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 18),
                      label: Text('Delete Group', style: TextStyle(color: AppColors.error)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.error),
                        minimumSize: const Size(double.infinity, 46),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _handleLeaveGroup(context, ref, group, members, isAdmin, myUserId);
                    },
                    icon: Icon(Icons.logout_rounded, color: AppColors.error, size: 18),
                    label: Text('Leave Group', style: TextStyle(color: AppColors.error)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.error),
                      minimumSize: const Size(double.infinity, 46),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _handleDeleteGroup(BuildContext context, WidgetRef ref, Group group) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Group'),
        content: const Text(
          'Are you sure you want to completely delete this group? All unsettled balances and expenses will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(groupRepositoryProvider).deleteGroup(group.id);
                ref.invalidate(userGroupsProvider);
                if (context.mounted) context.pop();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e', style: const TextStyle(color: Colors.white)),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _handleLeaveGroup(
    BuildContext context,
    WidgetRef ref,
    Group group,
    List<GroupMember> members,
    bool isAdmin,
    String myUserId,
  ) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Leave Group'),
        content: const Text('Are you sure you want to leave this group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(groupRepositoryProvider).leaveGroup(group.id, myUserId);
                ref.invalidate(userGroupsProvider);
                if (context.mounted) context.pop();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e', style: const TextStyle(color: Colors.white)),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: const Text('Leave', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
