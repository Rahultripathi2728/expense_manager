import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/date_helpers.dart';
import '../../../shared/services/categorize_service.dart';
import '../../../core/services/export_service.dart';
import '../../../shared/widgets/animation_helpers.dart';
import '../data/expense_repository.dart';

class ViewAllExpensesPage extends ConsumerStatefulWidget {
  const ViewAllExpensesPage({super.key});

  @override
  ConsumerState<ViewAllExpensesPage> createState() =>
      _ViewAllExpensesPageState();
}

class _ViewAllExpensesPageState extends ConsumerState<ViewAllExpensesPage> {
  DateTime _selectedMonth = DateTime.now();
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
          PopupMenuButton<String>(
            icon: Icon(Icons.ios_share, color: AppColors.textPrimary),
            onSelected: (value) async {
              if (filtered.isEmpty) return;
              if (value == 'pdf') {
                await ExportService.exportToPDF(filtered);
              } else if (value == 'csv') {
                await ExportService.exportToCSV(filtered);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'pdf', child: Text('Export as PDF')),
              const PopupMenuItem(value: 'csv', child: Text('Export as CSV')),
            ],
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
                      avatar: Text(CategorizeService.iconForCategory(cat)),
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
            child: expensesAsync.when(
              loading: () => Center(
                child: CircularProgressIndicator(color: AppColors.textPrimary),
              ),
              error: (err, _) => Center(
                child: Text(
                  'Error loading expenses: $err',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
              data: (_) {
                if (filtered.isEmpty) {
                  return Center(
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
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final e = filtered[index];
                    final isGroup = e.expenseType == 'group';
                    final dotColor = e.isSettled
                        ? const Color(0xFF22C55E)
                        : isGroup
                        ? const Color(0xFFF97316)
                        : const Color(0xFF3B82F6);

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
                              backgroundColor: dotColor.withValues(alpha: 0.1),
                              child: Text(
                                CategorizeService.iconForCategory(e.category),
                                style: const TextStyle(fontSize: 18),
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
        ],
      ),
    );
  }
}
