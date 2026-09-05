import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/date_helpers.dart';
import '../../expenses/domain/expense_model.dart';
import '../../expenses/presentation/utils/category_icon_helper.dart';

class BillSelectionPage extends ConsumerStatefulWidget {
  final String groupId;
  final List<Expense> unsettledExpenses;

  const BillSelectionPage({
    super.key,
    required this.groupId,
    required this.unsettledExpenses,
  });

  @override
  ConsumerState<BillSelectionPage> createState() => _BillSelectionPageState();
}

class _BillSelectionPageState extends ConsumerState<BillSelectionPage> {
  final Set<String> _selectedExpenseIds = {};

  @override
  void initState() {
    super.initState();
    // Default to selecting all unsettled expenses
    _selectedExpenseIds.addAll(widget.unsettledExpenses.map((e) => e.id));
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedExpenseIds.contains(id)) {
        _selectedExpenseIds.remove(id);
      } else {
        _selectedExpenseIds.add(id);
      }
    });
  }

  void _onNext() {
    if (_selectedExpenseIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one bill to settle')),
      );
      return;
    }
    
    final selectedExpenses = widget.unsettledExpenses
        .where((e) => _selectedExpenseIds.contains(e.id))
        .toList();
        
    context.push(
      '/payment-summary',
      extra: {
        'groupId': widget.groupId,
        'expenses': selectedExpenses,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(
          'Select Bills to Settle',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: widget.unsettledExpenses.isEmpty
                ? Center(
                    child: Text('No unsettled bills', style: TextStyle(color: AppColors.textSecondary)),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: widget.unsettledExpenses.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final exp = widget.unsettledExpenses[index];
                      final isSelected = _selectedExpenseIds.contains(exp.id);

                      return GestureDetector(
                        onTap: () => _toggleSelection(exp.id),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary.withValues(alpha: 0.05) : AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : AppColors.borderLight,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            clipBehavior: Clip.antiAlias,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.surfaceVariant,
                                child: Icon(
                                  CategoryIconHelper.getIcon(exp.category),
                                  color: AppColors.textPrimary,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                exp.description,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              subtitle: Text(
                                'Total: ${DateHelpers.formatCurrency(exp.amount)}\n${DateHelpers.formatFullDate(exp.expenseDate)}',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                              ),
                              trailing: Checkbox(
                                value: isSelected,
                                activeColor: AppColors.primary,
                                onChanged: (val) {
                                  if (val != null) _toggleSelection(exp.id);
                                },
                              ),
                              isThreeLine: true,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          
          // Bottom Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: ElevatedButton(
                onPressed: _selectedExpenseIds.isEmpty ? null : _onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Next (${_selectedExpenseIds.length} bills selected)',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
