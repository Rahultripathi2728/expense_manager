import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/date_helpers.dart';
import '../../../core/utils/haptic_helper.dart';
import '../data/settlement_repository.dart';
import '../domain/settlement_model.dart';
import '../../profile/domain/profile_model.dart';
import 'settlement_page.dart'; // for groupBalancesProvider

class SettlementHistoryPage extends ConsumerStatefulWidget {
  final String groupId;

  const SettlementHistoryPage({super.key, required this.groupId});

  @override
  ConsumerState<SettlementHistoryPage> createState() => _SettlementHistoryPageState();
}

class _SettlementHistoryPageState extends ConsumerState<SettlementHistoryPage> {
  bool _isLoading = true;
  List<Settlement> _settlements = [];
  Map<String, Profile> _profiles = {};
  String? _error;

  // Filters
  DateTime? _selectedMonth; // null = All Months
  String? _selectedPersonId; // null = All Members

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final repo = ref.read(settlementRepositoryProvider);
      final settlements = await repo.getGroupSettlements(widget.groupId);

      final balancesData = await ref.read(groupBalancesProvider(widget.groupId).future);
      final profiles = balancesData.profiles;

      if (mounted) {
        setState(() {
          _settlements = settlements;
          _profiles = profiles;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _pickMonth() async {
    HapticHelper.lightTap();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter settlements
    final filtered = _settlements.where((s) {
      if (_selectedMonth != null) {
        if (s.createdAt.year != _selectedMonth!.year || s.createdAt.month != _selectedMonth!.month) {
          return false;
        }
      }
      if (_selectedPersonId != null) {
        if (s.fromUserId != _selectedPersonId && s.toUserId != _selectedPersonId) {
          return false;
        }
      }
      return true;
    }).toList();

    final totalSettledAmount = filtered.fold<double>(0.0, (sum, s) => sum + s.amount);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Settlement History',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textPrimary),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: InkWell(
            onTap: () {
              HapticHelper.lightTap();
              context.pop();
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary, size: 20),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline_rounded, color: AppColors.error, size: 40),
                      const SizedBox(height: 12),
                      Text('Error: $_error', style: TextStyle(color: AppColors.error)),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Filters Header
                    Container(
                      color: AppColors.surface,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Column(
                        children: [
                          // Month & Person Filter Chips
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              children: [
                                // Month Filter Chip
                                GestureDetector(
                                  onTap: _pickMonth,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: _selectedMonth != null
                                          ? AppColors.primary.withValues(alpha: 0.12)
                                          : AppColors.surfaceVariant,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: _selectedMonth != null
                                            ? AppColors.primary
                                            : AppColors.borderLight,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.calendar_month_rounded,
                                          size: 15,
                                          color: _selectedMonth != null
                                              ? AppColors.primary
                                              : AppColors.textSecondary,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _selectedMonth != null
                                              ? DateHelpers.formatMonthYear(_selectedMonth!)
                                              : 'All Months',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: _selectedMonth != null
                                                ? AppColors.primary
                                                : AppColors.textPrimary,
                                          ),
                                        ),
                                        if (_selectedMonth != null) ...[
                                          const SizedBox(width: 4),
                                          GestureDetector(
                                            onTap: () {
                                              setState(() => _selectedMonth = null);
                                            },
                                            child: const Icon(Icons.close_rounded, size: 14, color: Colors.grey),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Person Filter Dropdown Chip
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _selectedPersonId != null
                                        ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                        : AppColors.surfaceVariant,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: _selectedPersonId != null
                                          ? const Color(0xFF10B981)
                                          : AppColors.borderLight,
                                    ),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String?>(
                                      value: _selectedPersonId,
                                      isDense: true,
                                      icon: const Icon(Icons.arrow_drop_down_rounded, size: 20),
                                      hint: Row(
                                        children: [
                                          Icon(
                                            Icons.person_outline_rounded,
                                            size: 15,
                                            color: AppColors.textSecondary,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'All Members',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      items: [
                                        const DropdownMenuItem<String?>(
                                          value: null,
                                          child: Text('All Members', style: TextStyle(fontSize: 12)),
                                        ),
                                        ..._profiles.entries.map((e) {
                                          return DropdownMenuItem<String?>(
                                            value: e.key,
                                            child: Text(
                                              e.value.fullName,
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                          );
                                        }),
                                      ],
                                      onChanged: (val) {
                                        HapticHelper.selectionClick();
                                        setState(() => _selectedPersonId = val);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Summary Bar
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${filtered.length} ${filtered.length == 1 ? 'Settlement' : 'Settlements'} found',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  'Total: ${DateHelpers.formatCurrency(totalSettledAmount)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Settlements List
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceVariant,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.receipt_long_rounded,
                                        size: 44,
                                        color: AppColors.textTertiary,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No Settlements Match Filter',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Try selecting a different month or member.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.separated(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                              itemCount: filtered.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final settlement = filtered[index];
                                final fromName = _profiles[settlement.fromUserId]?.fullName ?? 'User';
                                final toName = _profiles[settlement.toUserId]?.fullName ?? 'User';

                                return InkWell(
                                  onTap: () {
                                    HapticHelper.lightTap();
                                    context.push(
                                      '/settlement-history-detail',
                                      extra: {
                                        'settlement': settlement,
                                        'fromName': fromName,
                                        'toName': toName,
                                      },
                                    );
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
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(6),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: const Icon(
                                                    Icons.check_circle_rounded,
                                                    size: 16,
                                                    color: Color(0xFF10B981),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  DateHelpers.formatFullDate(settlement.createdAt),
                                                  style: TextStyle(
                                                    color: AppColors.textSecondary,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Text(
                                              DateHelpers.formatCurrency(settlement.amount),
                                              style: const TextStyle(
                                                color: Color(0xFF10B981),
                                                fontWeight: FontWeight.w800,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: AppColors.surfaceVariant.withValues(alpha: 0.6),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  fromName,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                                child: Icon(
                                                  Icons.arrow_forward_rounded,
                                                  size: 14,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                              Flexible(
                                                child: Text(
                                                  toName,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '${settlement.settledExpenseIds.length} ${settlement.settledExpenseIds.length == 1 ? 'bill' : 'bills'} settled',
                                              style: TextStyle(
                                                color: AppColors.textTertiary,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            Row(
                                              children: [
                                                Text(
                                                  'View Details',
                                                  style: TextStyle(
                                                    color: AppColors.primary,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(width: 2),
                                                Icon(
                                                  Icons.chevron_right_rounded,
                                                  size: 14,
                                                  color: AppColors.primary,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}
