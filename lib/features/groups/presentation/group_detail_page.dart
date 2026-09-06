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
import '../../settlement/domain/settlement_model.dart';
import '../../profile/domain/profile_model.dart';
import 'group_balances_detail_page.dart' show buildHisaabBreakdownContent;

abstract class GroupActivityItem {
  DateTime get timestamp;
}

class ExpenseActivityItem implements GroupActivityItem {
  final Expense expense;
  ExpenseActivityItem(this.expense);
  @override
  DateTime get timestamp => expense.expenseDate;
}

class SettlementActivityItem implements GroupActivityItem {
  final Settlement settlement;
  SettlementActivityItem(this.settlement);
  @override
  DateTime get timestamp => settlement.createdAt;
}

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
  String _activityTypeFilter = 'all'; // 'all', 'expenses', 'settlements'
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
                    Tab(text: 'Group Activity'),
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

              // Tab 2: Group Activity Timeline (Expenses & Settlements)
              _buildActivityTab(group, profilesAsync.valueOrNull ?? []),
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
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            child: buildHisaabBreakdownContent(
              context: context,
              group: group,
              data: data,
              currentUser: currentUser,
              showHeroHeader: true,
            ),
          );
        },
      ),
    );
  }

  Widget _buildActivityTab(Group group, List<Profile> profiles) {
    final allExpensesAsync = ref.watch(groupAllExpensesProvider(group.id));
    final balancesAsync = ref.watch(groupBalancesProvider(group.id));
    final profileMap = {for (var p in profiles) p.userId: p};
    final hasActiveFilter = _statusFilter != 'all' ||
        _customDateRange != null ||
        _selectedCategoryFilter != null ||
        _activityTypeFilter != 'all';

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

        // Activity Stream Content
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
              error: (err, _) => Center(child: Text('Error loading activities: $err')),
              data: (expenses) {
                final balancesData = balancesAsync.valueOrNull;
                final settlements = balancesData?.settlements ?? [];

                // Combine into GroupActivityItems
                final List<GroupActivityItem> allItems = [
                  ...expenses.map((e) => ExpenseActivityItem(e)),
                  ...settlements.map((s) => SettlementActivityItem(s)),
                ];

                // Filter items
                final filtered = allItems.where((item) {
                  // Date Filter
                  if (_customDateRange != null) {
                    if (item.timestamp.isBefore(_customDateRange!.start) ||
                        item.timestamp.isAfter(_customDateRange!.end.add(const Duration(days: 1)))) {
                      return false;
                    }
                  } else {
                    if (item.timestamp.year != _selectedExpenseMonth.year ||
                        item.timestamp.month != _selectedExpenseMonth.month) {
                      return false;
                    }
                  }

                  // Activity Type filter
                  if (_activityTypeFilter == 'expenses' && item is! ExpenseActivityItem) {
                    return false;
                  }
                  if (_activityTypeFilter == 'settlements' && item is! SettlementActivityItem) {
                    return false;
                  }

                  // Status & Category filter for Expenses
                  if (item is ExpenseActivityItem) {
                    final exp = item.expense;
                    bool isExpSettled = exp.isSettled;
                    if (!isExpSettled && balancesData != null) {
                      isExpSettled = balancesData.isExpenseFullySettled(exp);
                    }
                    if (_statusFilter == 'settled' && !isExpSettled) return false;
                    if (_statusFilter == 'unsettled' && isExpSettled) return false;

                    if (_selectedCategoryFilter != null &&
                        exp.category.toLowerCase() != _selectedCategoryFilter!.toLowerCase()) {
                      return false;
                    }
                  }

                  return true;
                }).toList();

                // Sort newest first
                filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));

                final filteredExpenses = filtered.whereType<ExpenseActivityItem>().map((e) => e.expense).toList();
                final filteredSettlements = filtered.whereType<SettlementActivityItem>().map((s) => s.settlement).toList();

                final totalExpenseAmount = filteredExpenses.fold<double>(0.0, (sum, e) => sum + e.amount);
                final totalSettledAmount = filteredSettlements.fold<double>(0.0, (sum, s) => sum + s.amount);

                // Group by chronological date
                final Map<String, List<GroupActivityItem>> groupedActivities = {};
                for (final item in filtered) {
                  final title = _getDateGroupTitle(item.timestamp);
                  groupedActivities.putIfAbsent(title, () => []).add(item);
                }

                return Column(
                  children: [
                    // Activity Type Filter Chips
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildActivityTypePill(
                              label: 'All (${allItems.length})',
                              isSelected: _activityTypeFilter == 'all',
                              onTap: () => setState(() => _activityTypeFilter = 'all'),
                            ),
                            const SizedBox(width: 8),
                            _buildActivityTypePill(
                              label: 'Expenses (${expenses.length})',
                              isSelected: _activityTypeFilter == 'expenses',
                              icon: Icons.receipt_long_rounded,
                              onTap: () => setState(() => _activityTypeFilter = 'expenses'),
                            ),
                            const SizedBox(width: 8),
                            _buildActivityTypePill(
                              label: 'Settlements (${settlements.length})',
                              isSelected: _activityTypeFilter == 'settlements',
                              icon: Icons.payments_rounded,
                              onTap: () => setState(() => _activityTypeFilter = 'settlements'),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Main Timeline List
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.feed_outlined, size: 56, color: AppColors.textTertiary),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No Activities Found',
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
                                          : 'No expenses or settlements recorded for ${DateHelpers.formatMonthYear(_selectedExpenseMonth)}',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                    ),
                                    if (hasActiveFilter) ...[
                                      const SizedBox(height: 16),
                                      TextButton.icon(
                                        onPressed: () {
                                          setState(() {
                                            _statusFilter = 'all';
                                            _activityTypeFilter = 'all';
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
                            )
                          : ListView(
                              physics: const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics(),
                              ),
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                              children: [
                                // Summary row
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6, top: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${filtered.length} ${filtered.length == 1 ? 'Activity' : 'Activities'}',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      Text(
                                        totalSettledAmount > 0
                                            ? 'Exp: ₹${totalExpenseAmount.toStringAsFixed(0)} • Paid: ₹${totalSettledAmount.toStringAsFixed(0)}'
                                            : 'Total: ₹${totalExpenseAmount.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Chronologically grouped items
                                for (final entry in groupedActivities.entries) ...[
                                  // Date group header
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(2, 12, 2, 8),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                                          decoration: BoxDecoration(
                                            color: entry.key == 'Today'
                                                ? AppColors.primary.withValues(alpha: 0.12)
                                                : AppColors.surfaceVariant,
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: entry.key == 'Today'
                                                  ? AppColors.primary.withValues(alpha: 0.25)
                                                  : AppColors.borderLight,
                                            ),
                                          ),
                                          child: Text(
                                            entry.key,
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.bold,
                                              color: entry.key == 'Today'
                                                  ? AppColors.primary
                                                  : AppColors.textSecondary,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Divider(
                                            color: AppColors.borderLight,
                                            thickness: 0.8,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Tiles
                                  for (final item in entry.value) ...[
                                    if (item is ExpenseActivityItem)
                                      _buildExpenseActivityTile(
                                        item.expense,
                                        profileMap[item.expense.userId],
                                        balancesData,
                                      )
                                    else if (item is SettlementActivityItem)
                                      _buildSettlementActivityTile(
                                        item.settlement,
                                        profileMap[item.settlement.fromUserId],
                                        profileMap[item.settlement.toUserId],
                                      ),
                                  ],
                                ],
                              ],
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  String _getDateGroupTitle(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final itemDate = DateTime(date.year, date.month, date.day);

    if (itemDate == today) {
      return 'Today';
    } else if (itemDate == yesterday) {
      return 'Yesterday';
    } else if (date.year == now.year) {
      return DateHelpers.formatDayMonth(date);
    } else {
      return DateHelpers.formatFullDate(date);
    }
  }

  Widget _buildActivityTypePill({
    required String label,
    required bool isSelected,
    IconData? icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : AppColors.surfaceVariant.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.borderLight,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseActivityTile(
    Expense exp,
    Profile? payer,
    GroupBalanceData? balancesData,
  ) {
    final isFully = balancesData?.isExpenseFullySettled(exp) ?? exp.isSettled;
    final isPart = balancesData?.isExpensePartiallyOrFullySettled(exp) ?? false;

    final String badgeText;
    final Color badgeColor;

    if (isFully) {
      badgeText = 'Settled';
      badgeColor = const Color(0xFF10B981);
    } else if (isPart) {
      badgeText = 'Partially Settled';
      badgeColor = const Color(0xFF3B82F6);
    } else {
      badgeText = 'Unsettled';
      badgeColor = const Color(0xFFF59E0B);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            context.push('/expense-detail', extra: exp);
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
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
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.categoryColor(exp.category).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      CategoryIconHelper.getIcon(exp.category),
                      color: AppColors.categoryColor(exp.category),
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exp.description,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Paid by ${payer?.fullName ?? 'Member'} • ${DateHelpers.formatDayMonth(exp.expenseDate)}',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      DateHelpers.formatCurrency(exp.amount),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: badgeColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettlementActivityTile(
    Settlement settlement,
    Profile? fromProfile,
    Profile? toProfile,
  ) {
    final fromName = fromProfile?.fullName.trim().isNotEmpty == true ? fromProfile!.fullName : 'Member';
    final toName = toProfile?.fullName.trim().isNotEmpty == true ? toProfile!.fullName : 'Member';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            context.push('/settlement-history', extra: widget.groupId);
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.payments_rounded,
                      color: Color(0xFF10B981),
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                          children: [
                            TextSpan(
                              text: fromName,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const TextSpan(text: ' paid '),
                            TextSpan(
                              text: toName,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF10B981)),
                          const SizedBox(width: 4),
                          Text(
                            'Settlement Payment • ${DateHelpers.formatDayMonth(settlement.createdAt)}',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      DateHelpers.formatCurrency(settlement.amount),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Settled ✅',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
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
