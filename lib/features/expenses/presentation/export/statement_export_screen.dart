import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/theme_provider.dart';
import '../../../../core/services/export_models.dart';
import '../../../../core/services/export_service.dart';
import '../../../../core/utils/date_helpers.dart';
import '../../../../core/utils/haptic_helper.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../groups/data/group_repository.dart';
import '../../../groups/domain/group_model.dart';
import '../../../profile/data/profile_repository.dart';
import '../../../settlement/data/settlement_repository.dart';

class StatementExportScreen extends ConsumerStatefulWidget {
  final DateTime? initialMonth;
  final DateTimeRange? initialDateRange;

  const StatementExportScreen({
    super.key,
    this.initialMonth,
    this.initialDateRange,
  });

  @override
  ConsumerState<StatementExportScreen> createState() =>
      _StatementExportScreenState();
}

class _StatementExportScreenState extends ConsumerState<StatementExportScreen> {
  late DateTime _startDate;
  late DateTime _endDate;
  String _selectedPreset = 'month'; // 'month', 'last_month', 'last_3_months', 'custom'
  String _scope = 'all'; // 'all', 'expenses', 'settlements'
  String _expenseFilter = 'all'; // 'all', 'personal', 'group'

  bool _isExportingPdf = false;
  bool _isExportingCsv = false;
  Map<String, int> _groupMemberCounts = {};
  bool _isLoadingGroupCounts = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final baseMonth = widget.initialMonth ?? DateTime(now.year, now.month, 1);

    if (widget.initialDateRange != null) {
      _startDate = widget.initialDateRange!.start;
      _endDate = widget.initialDateRange!.end;
      _selectedPreset = 'custom';
    } else {
      _startDate = DateTime(baseMonth.year, baseMonth.month, 1);
      _endDate = DateTime(baseMonth.year, baseMonth.month + 1, 0, 23, 59, 59);
      _selectedPreset = 'month';
    }

    _loadGroupMemberCounts();
  }

  Future<void> _loadGroupMemberCounts() async {
    setState(() => _isLoadingGroupCounts = true);
    try {
      final groups = await ref.read(userGroupsProvider.future);
      final repo = ref.read(groupRepositoryProvider);
      final Map<String, int> counts = {};

      for (final g in groups) {
        try {
          final members = await repo.getGroupMembers(g.id);
          counts[g.id] = members.length;
        } catch (_) {
          counts[g.id] = 1;
        }
      }

      if (mounted) {
        setState(() {
          _groupMemberCounts = counts;
          _isLoadingGroupCounts = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingGroupCounts = false);
      }
    }
  }

  void _applyPreset(String preset) {
    HapticHelper.lightTap();
    final now = DateTime.now();
    setState(() {
      _selectedPreset = preset;
      if (preset == 'month') {
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      } else if (preset == 'last_month') {
        final lastMonth = DateTime(now.year, now.month - 1, 1);
        _startDate = DateTime(lastMonth.year, lastMonth.month, 1);
        _endDate = DateTime(lastMonth.year, lastMonth.month + 1, 0, 23, 59, 59);
      } else if (preset == 'last_3_months') {
        final threeMonthsAgo = DateTime(now.year, now.month - 2, 1);
        _startDate = DateTime(threeMonthsAgo.year, threeMonthsAgo.month, 1);
        _endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      }
    });
  }

  Future<void> _pickCustomRange() async {
    HapticHelper.mediumTap();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedPreset = 'custom';
        _startDate = DateTime(picked.start.year, picked.start.month, picked.start.day);
        _endDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
      });
    }
  }

  List<DateTime> _getMonthsInRange(DateTime start, DateTime end) {
    final List<DateTime> months = [];
    DateTime current = DateTime(start.year, start.month, 1);
    final DateTime endMonth = DateTime(end.year, end.month, 1);

    while (!current.isAfter(endMonth)) {
      months.add(current);
      current = DateTime(current.year, current.month + 1, 1);
    }
    return months;
  }

  StatementExportData _compileExportData({
    required String userName,
    required String userEmail,
    required String? userUpiId,
    required List<Group> rawGroups,
    required List<CashFlowActivityItem> allActivities,
  }) {
    // 1. Enrolled groups info
    final List<GroupSummaryInfo> groups = rawGroups.map((g) {
      final count = _groupMemberCounts[g.id] ?? 1;
      return GroupSummaryInfo(
        id: g.id,
        name: g.name,
        memberCount: count,
      );
    }).toList();

    // 2. Filter activities by date range
    final inRangeActivities = allActivities.where((a) {
      return a.date.isAfter(_startDate.subtract(const Duration(seconds: 1))) &&
          a.date.isBefore(_endDate.add(const Duration(seconds: 1)));
    }).toList();

    // 3. Filter activities by scope & expenseFilter
    final List<StatementTransactionItem> items = [];
    double totalSpent = 0.0;
    double totalReceived = 0.0;
    double totalPaid = 0.0;
    final Map<String, double> categoryBreakdown = {};

    for (final act in inRangeActivities) {
      final isExp = act.type == CashFlowType.expense;
      final isRecv = act.type == CashFlowType.settlementReceived;
      final isPaid = act.type == CashFlowType.settlementPaid;

      if (_scope == 'expenses') {
        if (!isExp) continue;
        final isPersonal = act.groupName == 'Personal';
        if (_expenseFilter == 'personal' && !isPersonal) continue;
        if (_expenseFilter == 'group' && isPersonal) continue;
      } else if (_scope == 'settlements') {
        if (!isRecv && !isPaid) continue;
      }

      final isOutflow = isExp || isPaid;
      final cat = (act.category == null || act.category!.isEmpty) ? 'General' : act.category!;
      if (isExp) {
        totalSpent += act.amount;
        categoryBreakdown[cat] = (categoryBreakdown[cat] ?? 0.0) + act.amount;
      } else if (isRecv) {
        totalReceived += act.amount;
      } else if (isPaid) {
        totalPaid += act.amount;
      }

      items.add(
        StatementTransactionItem(
          id: act.id,
          dateTime: act.date,
          title: act.title,
          groupName: act.groupName ?? 'General',
          payerName: act.payerName ?? 'You',
          category: cat,
          amount: act.amount,
          isOutflow: isOutflow,
          isSettlement: !isExp,
          subtitle: act.subtitle,
        ),
      );
    }

    // Sort items newest first
    items.sort((a, b) => b.dateTime.compareTo(a.dateTime));

    final double netBalance;
    if (_scope == 'expenses') {
      netBalance = -totalSpent;
    } else if (_scope == 'settlements') {
      netBalance = totalReceived - totalPaid;
    } else {
      netBalance = totalReceived - (totalSpent + totalPaid);
    }

    return StatementExportData(
      userName: userName,
      userEmail: userEmail,
      userUpiId: userUpiId,
      groups: groups,
      scope: _scope,
      expenseFilter: _expenseFilter,
      startDate: _startDate,
      endDate: _endDate,
      items: items,
      totalSpent: totalSpent,
      totalReceived: totalReceived,
      netBalance: netBalance,
      categoryBreakdown: categoryBreakdown,
    );
  }

  Future<void> _handleExportPDF(StatementExportData data) async {
    if (data.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No transactions found to export for selected range.')),
      );
      return;
    }

    setState(() => _isExportingPdf = true);
    HapticHelper.mediumTap();

    try {
      await ExportService.exportStatementToPDF(data);
      HapticHelper.mediumTap();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'PDF Statement generated successfully!',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingPdf = false);
    }
  }

  Future<void> _handleExportCSV(StatementExportData data) async {
    if (data.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No transactions found to export for selected range.')),
      );
      return;
    }

    setState(() => _isExportingCsv = true);
    HapticHelper.mediumTap();

    try {
      await ExportService.exportStatementToCSV(data);
      HapticHelper.mediumTap();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'CSV Statement exported successfully!',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('CSV export failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingCsv = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);

    final user = ref.watch(authStateProvider).valueOrNull;
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final groups = ref.watch(userGroupsProvider).valueOrNull ?? [];

    final userName = profile?.fullName ?? user?.name ?? 'User';
    final userEmail = user?.email ?? profile?.userId ?? 'N/A';
    final userUpiId = profile?.upiId;

    // Collect all activities across selected months
    final months = _getMonthsInRange(_startDate, _endDate);
    final List<CashFlowActivityItem> combinedActivities = [];
    bool isLoading = false;

    for (final m in months) {
      final cfAsync = ref.watch(userCashFlowProvider(m));
      if (cfAsync.isLoading) {
        isLoading = true;
      }
      final cfData = cfAsync.valueOrNull;
      if (cfData != null) {
        combinedActivities.addAll(cfData.activities);
      }
    }

    // Deduplicate activities by ID if spanning multiple months
    final seenIds = <String>{};
    final uniqueActivities = <CashFlowActivityItem>[];
    for (final act in combinedActivities) {
      if (seenIds.add(act.id)) {
        uniqueActivities.add(act);
      }
    }

    final exportData = _compileExportData(
      userName: userName,
      userEmail: userEmail,
      userUpiId: userUpiId,
      rawGroups: groups,
      allActivities: uniqueActivities,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Export Statement',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
      ),
      bottomNavigationBar: _buildBottomActions(exportData),
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Account & Enrolled Groups Verification Card
                  _buildProfileCard(userName, userEmail, userUpiId, exportData.groups),
                  const SizedBox(height: 20),

                  // 2. Date Range Section
                  _buildDateRangeSection(),
                  const SizedBox(height: 20),

                  // 3. Statement Scope & Category Filter
                  _buildScopeSelector(),
                  const SizedBox(height: 20),

                  // 4. Live Summary KPI Cards (Scope-Tailored)
                  _buildLiveSummaryCards(exportData),
                  const SizedBox(height: 24),

                  // 5. Live Transactions Audit Table Preview
                  _buildTransactionsPreview(exportData),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileCard(
    String name,
    String email,
    String? upiId,
    List<GroupSummaryInfo> groups,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withValues(alpha: 0.75),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'VERIFIED',
                            style: TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (upiId != null && upiId.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.bolt_rounded, size: 13, color: AppColors.primary),
                          const SizedBox(width: 2),
                          Text(
                            'UPI: $upiId',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Enrolled Groups
          Row(
            children: [
              Icon(Icons.groups_rounded, size: 15, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                'Enrolled Groups (${groups.length})',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              if (_isLoadingGroupCounts) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          if (groups.isEmpty)
            Text(
              'No active groups found.',
              style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: groups.map((g) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Text(
                    '${g.name} (${g.memberCount} ${g.memberCount == 1 ? "member" : "members"})',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildDateRangeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'STATEMENT PERIOD',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),

        // Period Quick Presets
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildPresetChip('This Month', 'month'),
              const SizedBox(width: 8),
              _buildPresetChip('Last Month', 'last_month'),
              const SizedBox(width: 8),
              _buildPresetChip('Last 3 Months', 'last_3_months'),
              const SizedBox(width: 8),
              _buildPresetChip('Custom Range', 'custom', isCustom: true),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Date Display Selector
        GestureDetector(
          onTap: _pickCustomRange,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _selectedPreset == 'custom'
                    ? AppColors.primary
                    : AppColors.borderLight,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_month_rounded, color: AppColors.primary, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${DateHelpers.formatFullDate(_startDate)}  –  ${DateHelpers.formatFullDate(_endDate)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Icon(Icons.edit_calendar_rounded, color: AppColors.textTertiary, size: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPresetChip(String title, String key, {bool isCustom = false}) {
    final isSelected = _selectedPreset == key;
    return GestureDetector(
      onTap: isCustom ? _pickCustomRange : () => _applyPreset(key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.borderLight,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildScopeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'STATEMENT SCOPE',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(
              child: _buildScopeCard(
                title: 'All Activity',
                subtitle: 'Full Ledger',
                icon: Icons.all_inclusive_rounded,
                scopeKey: 'all',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildScopeCard(
                title: 'Expenses',
                subtitle: 'Purchases',
                icon: Icons.receipt_long_rounded,
                scopeKey: 'expenses',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildScopeCard(
                title: 'Settlements',
                subtitle: 'Peer Dues',
                icon: Icons.handshake_rounded,
                scopeKey: 'settlements',
              ),
            ),
          ],
        ),

        // If Expenses is selected, show sub-filter chips
        if (_scope == 'expenses') ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Filter Expenses Scope:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildSubFilterChip('All Expenses', 'all'),
                    const SizedBox(width: 6),
                    _buildSubFilterChip('Personal Only', 'personal'),
                    const SizedBox(width: 6),
                    _buildSubFilterChip('Group Only', 'group'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildScopeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required String scopeKey,
  }) {
    final isSelected = _scope == scopeKey;
    return GestureDetector(
      onTap: () {
        HapticHelper.lightTap();
        setState(() => _scope = scopeKey);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.08)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.borderLight,
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: AppColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubFilterChip(String label, String key) {
    final isSelected = _expenseFilter == key;
    return GestureDetector(
      onTap: () {
        HapticHelper.lightTap();
        setState(() => _expenseFilter = key);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.borderLight,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildLiveSummaryCards(StatementExportData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'LIVE STATEMENT SUMMARY',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: AppColors.textSecondary,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${data.items.length} Records',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Scope-tailored live KPI blocks
        if (data.scope == 'expenses') ...[
          // For expenses: Strictly show Total Spent and category breakdown!
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TOTAL EXPENSES SPENT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Icon(Icons.shopping_bag_outlined, color: AppColors.primary, size: 18),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  DateHelpers.formatCurrency(data.totalSpent),
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (data.categoryBreakdown.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Text(
                    'Category Breakdown',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: data.categoryBreakdown.entries.map((entry) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: Text(
                          '${entry.key}: ${DateHelpers.formatCurrency(entry.value)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ] else if (data.scope == 'settlements') ...[
          // For settlements: Paid Out, Received, and Net Settlement Position
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  title: 'PAID OUT',
                  amount: data.totalReceived - data.netBalance > 0 ? (data.totalReceived - data.netBalance) : 0.0,
                  color: const Color(0xFFEF4444),
                  icon: Icons.arrow_upward_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  title: 'RECEIVED',
                  amount: data.totalReceived,
                  color: const Color(0xFF10B981),
                  icon: Icons.arrow_downward_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildNetTile(
            title: 'NET SETTLEMENT POSITION',
            netAmount: data.netBalance,
          ),
        ] else ...[
          // Full statement: Outflow, Inflow, Net Cash Flow
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  title: 'TOTAL OUTFLOW',
                  amount: data.totalSpent + (data.totalReceived - data.netBalance - data.totalSpent > 0 ? data.totalReceived - data.netBalance - data.totalSpent : 0),
                  color: const Color(0xFFEF4444),
                  icon: Icons.arrow_upward_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  title: 'TOTAL INFLOW',
                  amount: data.totalReceived,
                  color: const Color(0xFF10B981),
                  icon: Icons.arrow_downward_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildNetTile(
            title: 'NET FINANCIAL POSITION',
            netAmount: data.netBalance,
          ),
        ],
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required double amount,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              Icon(icon, color: color, size: 14),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            DateHelpers.formatCurrency(amount),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetTile({
    required String title,
    required double netAmount,
  }) {
    final isPositive = netAmount >= 0;
    final color = isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            '${isPositive ? '+' : ''}${DateHelpers.formatCurrency(netAmount)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsPreview(StatementExportData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TRANSACTIONS PREVIEW',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),

        if (data.items.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 40,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(height: 8),
                Text(
                  'No transactions found',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Try expanding your date range or switching the scope.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: data.items.length > 20 ? 20 : data.items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = data.items[index];
                final isOutflow = item.isOutflow;
                final amountColor = isOutflow
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF10B981);

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isOutflow
                              ? const Color(0xFFEF4444).withValues(alpha: 0.1)
                              : const Color(0xFF10B981).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          item.isSettlement
                              ? (isOutflow ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)
                              : Icons.shopping_bag_outlined,
                          size: 16,
                          color: amountColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${DateHelpers.formatDayMonth(item.dateTime)} • ${item.groupName} • ${item.payerName}',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textTertiary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${isOutflow ? '-' : '+'}${DateHelpers.formatCurrency(item.amount)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: amountColor,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        if (data.items.length > 20) ...[
          const SizedBox(height: 8),
          Center(
            child: Text(
              '+ ${data.items.length - 20} more transactions included in statement export',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textTertiary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBottomActions(StatementExportData data) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.borderLight)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                icon: _isExportingPdf
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.picture_as_pdf_rounded, size: 18),
                label: Text(
                  _isExportingPdf ? 'Generating PDF...' : 'Download PDF',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                onPressed: _isExportingPdf || _isExportingCsv
                    ? null
                    : () => _handleExportPDF(data),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                icon: _isExportingCsv
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.textPrimary,
                        ),
                      )
                    : const Icon(Icons.table_chart_outlined, size: 18),
                label: Text(
                  _isExportingCsv ? '...' : 'CSV',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: BorderSide(color: AppColors.border),
                  minimumSize: const Size(0, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _isExportingPdf || _isExportingCsv
                    ? null
                    : () => _handleExportCSV(data),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
