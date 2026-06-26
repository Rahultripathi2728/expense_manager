import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/haptic_helper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'utils/category_icon_helper.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/date_helpers.dart';
import '../../../shared/services/categorize_service.dart';
import '../../../core/services/export_service.dart';
import '../../../shared/widgets/animation_helpers.dart';
import '../../../shared/widgets/skeleton_loading_card.dart';
import '../data/expense_repository.dart';

class ViewAllExpensesPage extends ConsumerStatefulWidget {
  const ViewAllExpensesPage({super.key});

  @override
  ConsumerState<ViewAllExpensesPage> createState() =>
      _ViewAllExpensesPageState();
}

class _ViewAllExpensesPageState extends ConsumerState<ViewAllExpensesPage> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  String? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(monthlyExpensesProvider(_selectedMonth));
    final expenses = expensesAsync.valueOrNull ?? [];

    var filtered = expenses;
    if (_selectedCategory != null) {
      filtered = expenses
          .where((e) => e.category == _selectedCategory)
          .toList();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(
          'All Expenses',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.ios_share, color: AppColors.textPrimary),
            onPressed: () => _showExportFilterSheet(context, filtered),
          ),
        ],
      ),
      body: Column(
        children: [
          // Month Selector Row
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(() {
                      _selectedMonth = DateHelpers.previousMonth(
                        _selectedMonth,
                      );
                    });
                  },
                ),
                Text(
                  DateHelpers.formatMonthYear(_selectedMonth),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    setState(() {
                      _selectedMonth = DateHelpers.nextMonth(_selectedMonth);
                    });
                  },
                ),
              ],
            ),
          ),

          // Category Filter Chips
          Container(
            height: 48,
            color: AppColors.surface,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('All'),
                    selected: _selectedCategory == null,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedCategory = null);
                      }
                    },
                    selectedColor: AppColors.borderLight,
                    checkmarkColor: AppColors.textPrimary,
                  ),
                ),
                ...CategorizeService.allCategories.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                    avatar: Icon(
                      CategoryIconHelper.getIcon(cat),
                      color: isSelected ? AppColors.onPrimary : AppColors.textPrimary,
                      size: 16,
                    ),
                    label: Text(CategorizeService.displayName(cat)),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedCategory = selected ? cat : null;
                        });
                      },
                      selectedColor: AppColors.borderLight,
                      checkmarkColor: AppColors.textPrimary,
                    ),
                  );
                }),
              ],
            ),
          ),
          const Divider(height: 1),

          // Expenses List
          Expanded(
            child: RefreshIndicator(
              color: AppColors.surface,
              backgroundColor: AppColors.textPrimary,
              strokeWidth: 3,
              onRefresh: () async {
                ref.invalidate(monthlyExpensesProvider(_selectedMonth));
                await Future.delayed(const Duration(milliseconds: 600));
              },
              child: expensesAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SkeletonList(itemCount: 6),
                ),
                error: (err, _) => Center(
                  child: Text(
                    'Error loading expenses: $err',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
                data: (_) {
                if (filtered.isEmpty) {
                  return CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    slivers: [
                      SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.receipt_long_outlined,
                                size: 64,
                                color: AppColors.border,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No expenses found',
                                style: TextStyle(
                                  color: AppColors.textTertiary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final e = filtered[index];
                    final isGroup = e.expenseType == 'group';

                    return StaggeredListItem(
                      index: index,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.borderLight,
                            width: 1,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: ListTile(
                            onTap: () =>
                                context.push('/expense-detail', extra: e),
                            leading: CircleAvatar(
                              backgroundColor: AppColors.surfaceVariant,
                              child: Icon(
                                CategoryIconHelper.getIcon(e.category),
                                color: AppColors.textPrimary,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              e.description,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            subtitle: Row(
                              children: [
                                Text(
                                  CategorizeService.displayName(e.category),
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.border,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  DateHelpers.formatDayMonth(e.expenseDate),
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  DateHelpers.formatCurrency(e.amount),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                if (isGroup)
                                  Text(
                                    'Group',
                                    style: TextStyle(
                                      color: AppColors.textTertiary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  )
                                else
                                  Text(
                                    'Personal',
                                    style: TextStyle(
                                      color: AppColors.textTertiary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
        ],
      ),
    );
  }

  void _showExportFilterSheet(BuildContext context, List expenses) {
    if (expenses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No expenses to export'), backgroundColor: Colors.orange),
      );
      return;
    }

    String? filterCategory;
    DateTime? startDate;
    DateTime? endDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          // Get unique categories from current expenses
          final categories = expenses
              .map((e) => e.category as String)
              .where((c) => c.isNotEmpty)
              .toSet()
              .toList()
            ..sort();

          // Apply local filter
          var exportExpenses = List.from(expenses);
          if (filterCategory != null) {
            exportExpenses = exportExpenses.where((e) => e.category == filterCategory).toList();
          }
          if (startDate != null) {
            exportExpenses = exportExpenses.where((e) => !e.expenseDate.isBefore(startDate!)).toList();
          }
          if (endDate != null) {
            final endOfDay = DateTime(endDate!.year, endDate!.month, endDate!.day, 23, 59, 59);
            exportExpenses = exportExpenses.where((e) => !e.expenseDate.isAfter(endOfDay)).toList();
          }

          return Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textTertiary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Export Expenses',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${exportExpenses.length} expense(s) will be exported',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),

                // Category Filter
                Text(
                  'Filter by Category',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'All',
                        isSelected: filterCategory == null,
                        onTap: () => setState(() => filterCategory = null),
                      ),
                      ...categories.map((cat) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: _FilterChip(
                          label: cat,
                          isSelected: filterCategory == cat,
                          onTap: () => setState(() => filterCategory = cat),
                        ),
                      )),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Date Range
                Text(
                  'Date Range',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: startDate ?? DateTime.now().subtract(const Duration(days: 30)),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) setState(() => startDate = picked);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.textTertiary.withValues(alpha: 0.3)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            startDate != null ? DateFormat('dd MMM yyyy').format(startDate!) : 'Start date',
                            style: TextStyle(
                              color: startDate != null ? AppColors.textPrimary : AppColors.textTertiary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.arrow_forward, size: 16, color: AppColors.textTertiary),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: endDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) setState(() => endDate = picked);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.textTertiary.withValues(alpha: 0.3)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            endDate != null ? DateFormat('dd MMM yyyy').format(endDate!) : 'End date',
                            style: TextStyle(
                              color: endDate != null ? AppColors.textPrimary : AppColors.textTertiary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (startDate != null || endDate != null)
                      IconButton(
                        icon: Icon(Icons.clear, size: 18, color: AppColors.textSecondary),
                        onPressed: () => setState(() {
                          startDate = null;
                          endDate = null;
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 24),

                // Export Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.picture_as_pdf, size: 18),
                        label: const Text('PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.textPrimary,
                          foregroundColor: AppColors.surface,
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: exportExpenses.isEmpty
                            ? null
                            : () async {
                                HapticHelper.mediumTap();
                                Navigator.pop(context);
                                await ExportService.exportToPDF(exportExpenses.cast());
                              },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.table_chart_outlined, size: 18),
                        label: const Text('CSV', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: BorderSide(color: AppColors.textPrimary),
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: exportExpenses.isEmpty
                            ? null
                            : () async {
                                HapticHelper.mediumTap();
                                Navigator.pop(context);
                                await ExportService.exportToCSV(exportExpenses.cast());
                              },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticHelper.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.textPrimary : Colors.transparent,
          border: Border.all(
            color: isSelected ? AppColors.textPrimary : AppColors.textTertiary.withValues(alpha: 0.3),
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? AppColors.surface : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
