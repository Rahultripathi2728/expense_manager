import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:appwrite/appwrite.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/constants/app_constants.dart';
import '../../../core/utils/date_helpers.dart';
import '../../../core/appwrite_client.dart';
import '../domain/settlement_model.dart';
import '../../expenses/data/expense_repository.dart';
import '../../expenses/domain/expense_model.dart';
import '../../expenses/domain/expense_split_model.dart';
import '../../expenses/presentation/utils/category_icon_helper.dart';

class SettlementHistoryDetailPage extends ConsumerStatefulWidget {
  final Settlement settlement;
  final String fromName;
  final String toName;

  const SettlementHistoryDetailPage({
    super.key,
    required this.settlement,
    required this.fromName,
    required this.toName,
  });

  @override
  ConsumerState<SettlementHistoryDetailPage> createState() => _SettlementHistoryDetailPageState();
}

class _SettlementHistoryDetailPageState extends ConsumerState<SettlementHistoryDetailPage> {
  bool _isLoading = true;
  List<Expense> _expenses = [];
  Map<String, List<ExpenseSplit>> _splitsByExpenseId = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadExpensesAndSplits();
  }

  Future<void> _loadExpensesAndSplits() async {
    try {
      final tablesDB = ref.read(appwriteTablesDBProvider);
      final repo = ref.read(expenseRepositoryProvider);

      if (widget.settlement.settledExpenseIds.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final res = await tablesDB.listRows(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.expensesCollection,
        queries: [
          Query.equal('\$id', widget.settlement.settledExpenseIds),
        ],
      );

      final expenses = res.rows.map((d) => Expense.fromMap(d.data)).toList();
      final Map<String, List<ExpenseSplit>> splitsMap = {};

      for (final exp in expenses) {
        try {
          final splits = await repo.getExpenseSplits(exp.id);
          splitsMap[exp.id] = splits;
        } catch (_) {}
      }

      setState(() {
        _expenses = expenses;
        _splitsByExpenseId = splitsMap;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Settlement Breakdown'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.red)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    // Summary Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.surface,
                            AppColors.surfaceVariant.withValues(alpha: 0.5),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.borderLight),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF10B981)),
                                const SizedBox(width: 6),
                                Text(
                                  'Settled on ${DateHelpers.formatFullDate(widget.settlement.createdAt)}',
                                  style: const TextStyle(
                                    color: Color(0xFF10B981),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Payer
                              Column(
                                children: [
                                  Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [AppColors.primary, const Color(0xFF41A5FF)],
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        widget.fromName.isNotEmpty ? widget.fromName[0].toUpperCase() : 'U',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(widget.fromName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  Text('Payer', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                                ],
                              ),

                              // Amount & Arrow
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: Column(
                                  children: [
                                    Text(
                                      'PAID',
                                      style: TextStyle(
                                        color: AppColors.textTertiary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.arrow_forward_rounded, color: AppColors.primary, size: 20),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      DateHelpers.formatCurrency(widget.settlement.amount),
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 20,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Recipient
                              Column(
                                children: [
                                  Container(
                                    width: 52,
                                    height: 52,
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [Color(0xFF8B5CF6), Color(0xFFC084FC)],
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        widget.toName.isNotEmpty ? widget.toName[0].toUpperCase() : 'U',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(widget.toName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  Text('Receiver', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'BILLS INCLUDED IN THIS SETTLEMENT (${_expenses.length})',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (_expenses.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(child: Text('No itemized bills recorded for this settlement.')),
                      )
                    else
                      ..._expenses.map((exp) {
                        final splits = _splitsByExpenseId[exp.id] ?? [];
                        final fromSplit = splits.where((s) => s.userId == widget.settlement.fromUserId).firstOrNull;

                        final fromOwed = fromSplit?.amountOwed ?? (exp.amount / (splits.isNotEmpty ? splits.length : 2));

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
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
                                children: [
                                  CategoryIconHelper.buildBadge(exp.category, size: 38, iconSize: 18),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          exp.description.isNotEmpty ? exp.description : exp.category,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          DateHelpers.formatFullDate(exp.expenseDate),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '₹${exp.amount.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        'Total Bill',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textTertiary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Divider(height: 1),
                              const SizedBox(height: 10),

                              // Share breakdown row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          "${widget.fromName}'s Share",
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '₹${fromOwed.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceVariant,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      (exp.splitType ?? 'equal').toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
    );
  }
}
