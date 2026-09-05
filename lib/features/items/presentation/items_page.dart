import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../auth/data/auth_repository.dart';
import '../../groups/data/group_repository.dart';
import '../../groups/domain/group_model.dart';
import '../data/items_repository.dart';
import '../domain/group_item_model.dart';
import 'add_item_screen.dart';
import '../../expenses/presentation/add_expense/add_expense_screen.dart';
import '../../expenses/presentation/add_expense/providers/add_expense_provider.dart';
import '../../../../shared/services/categorize_service.dart';

class ItemsPage extends ConsumerStatefulWidget {
  const ItemsPage({super.key});

  @override
  ConsumerState<ItemsPage> createState() => _ItemsPageState();
}

class _ItemsPageState extends ConsumerState<ItemsPage> {
  // 'all', 'personal', or groupId
  String _selectedTab = 'all';
  final Set<String> _selectedItemIds = {};

  void _toggleItemSelection(String id) {
    HapticHelper.selectionClick();
    setState(() {
      if (_selectedItemIds.contains(id)) {
        _selectedItemIds.remove(id);
      } else {
        _selectedItemIds.add(id);
      }
    });
  }

  void _logMultipleAsExpense(List<GroupItem> allItems, List<Group> groups) {
    final selectedItems = allItems.where((i) => _selectedItemIds.contains(i.id)).toList();
    if (selectedItems.isEmpty) return;

    // Determine target group if all selected are in the same group
    Group? targetGroup;
    final firstGroup = selectedItems.first.groupId;
    final allSameGroup = selectedItems.every((i) => i.groupId == firstGroup);

    if (allSameGroup && firstGroup.isNotEmpty && firstGroup != 'personal') {
      targetGroup = groups.where((g) => g.id == firstGroup).firstOrNull;
    }

    if (selectedItems.length == 1) {
      final item = selectedItems.first;
      final desc = item.quantity.trim().isNotEmpty
          ? '${item.title} (${item.quantity.trim()})'
          : item.title;
      setState(() {
        _selectedItemIds.clear();
      });
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (_) => AddExpenseScreen(
            group: targetGroup,
            initialDescription: desc,
            initialCategory: CategorizeService.categorize(item.title),
            initialDate: DateTime.now(),
          ),
        ),
      );
      return;
    }

    _showMultiItemOptionsSheet(context, selectedItems, targetGroup);
  }

  void _showMultiItemOptionsSheet(
    BuildContext context,
    List<GroupItem> selectedItems,
    Group? targetGroup,
  ) {
    HapticHelper.mediumTap();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.textTertiary.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Log ${selectedItems.length} Items as Expense',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Select how to organize these items in your bill',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: selectedItems.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final item = selectedItems[index];
                      final label = item.quantity.trim().isNotEmpty
                          ? '${item.title} (${item.quantity.trim()})'
                          : item.title;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                _buildOptionCard(
                  icon: Icons.receipt_long_rounded,
                  iconColor: const Color(0xFF10B981),
                  title: 'Combine into 1 Bill',
                  subtitle: 'Single bill with all items pre-filled as itemized splits.',
                  badgeText: 'Itemwise',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    HapticHelper.mediumTap();
                    setState(() => _selectedItemIds.clear());

                    final combinedDesc = selectedItems
                        .map((i) => i.quantity.trim().isNotEmpty ? '${i.title} (${i.quantity.trim()})' : i.title)
                        .join(', ');

                    final itemSplits = selectedItems.map((i) {
                      final name = i.quantity.trim().isNotEmpty ? '${i.title} (${i.quantity.trim()})' : i.title;
                      return ItemSplitState(
                        description: name,
                        qty: 1,
                        price: 0.0,
                        participantIds: const [],
                      );
                    }).toList();

                    final bill = SingleBillState(
                      description: 'Items: $combinedDesc',
                      category: 'Groceries',
                      splitType: 'itemwise',
                      items: itemSplits,
                    );

                    ref.read(addExpenseProvider(targetGroup?.id).notifier).initializeWithBills([bill]);

                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(
                        builder: (_) => AddExpenseScreen(
                          group: targetGroup,
                          initialBills: [bill],
                          initialDate: DateTime.now(),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildOptionCard(
                  icon: Icons.view_carousel_rounded,
                  iconColor: const Color(0xFF8B5CF6),
                  title: 'Log as Separate Bills',
                  subtitle: 'Each item gets its own bill tab in a multi-bill view.',
                  badgeText: '${selectedItems.length} Tabs',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    HapticHelper.mediumTap();
                    setState(() => _selectedItemIds.clear());

                    final bills = selectedItems.map((item) {
                      final desc = item.quantity.trim().isNotEmpty ? '${item.title} (${item.quantity.trim()})' : item.title;
                      return SingleBillState(
                        description: desc,
                        category: CategorizeService.categorize(item.title),
                        amount: 0.0,
                        splitType: 'equal',
                      );
                    }).toList();

                    ref.read(addExpenseProvider(targetGroup?.id).notifier).initializeWithBills(bills);

                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(
                        builder: (_) => AddExpenseScreen(
                          group: targetGroup,
                          initialBills: bills,
                          initialDate: DateTime.now(),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOptionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String badgeText,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight, width: 1.2),
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
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: iconColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(userGroupsProvider);
    final currentUser = ref.watch(authStateProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(
          'Shopping & Items',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          if (_selectedItemIds.isNotEmpty)
            TextButton(
              onPressed: () {
                setState(() => _selectedItemIds.clear());
              },
              child: const Text('Clear', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: () {
                    final groups = groupsAsync.valueOrNull ?? [];
                    _showAddOptionsModal(context, groups);
                  },
                  icon: const Icon(Icons.add_rounded, size: 22, color: Colors.white),
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                ),
              ),
            ),
        ],
      ),
      body: groupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text('Error loading groups: $err', style: const TextStyle(color: Colors.red)),
        ),
        data: (groups) {
          final AsyncValue<List<GroupItem>> itemsAsync;

          if (_selectedTab == 'all') {
            itemsAsync = ref.watch(allUserItemsProvider);
          } else if (_selectedTab == 'personal') {
            itemsAsync = ref.watch(personalItemsProvider);
          } else {
            itemsAsync = ref.watch(groupItemsProvider(_selectedTab));
          }

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              ref.invalidate(allUserItemsProvider);
              ref.invalidate(personalItemsProvider);
              if (_selectedTab != 'all' && _selectedTab != 'personal') {
                ref.invalidate(groupItemsProvider(_selectedTab));
              }
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                // Top Segmented Switcher
                SliverToBoxAdapter(
                  child: Container(
                    color: AppColors.surface,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          _buildTabChip('all', 'All Items', Icons.all_inbox_rounded),
                          const SizedBox(width: 8),
                          _buildTabChip('personal', 'Personal', Icons.person_rounded),
                          const SizedBox(width: 8),
                          ...groups.map((g) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _buildTabChip(g.id, g.name, Icons.groups_rounded),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ),

                // Items List
                itemsAsync.when(
                  loading: () => const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (err, _) => SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text('Error: $err', style: const TextStyle(color: Colors.red)),
                    ),
                  ),
                  data: (itemList) {
                    if (itemList.isEmpty) {
                      return SliverFillRemaining(
                        hasScrollBody: false,
                        child: _buildEmptyState(),
                      );
                    }

                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final item = itemList[index];
                            final isOwner = currentUser != null && (item.addedBy == currentUser.id || item.addedBy.isEmpty);
                            final group = groups.where((g) => g.id == item.groupId).firstOrNull;

                            return _buildItemCard(
                              context,
                              item,
                              isOwner,
                              group,
                              currentUser,
                              itemList,
                              groups,
                            );
                          },
                          childCount: itemList.length,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
      bottomSheet: _selectedItemIds.isNotEmpty
          ? Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.borderLight)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final groups = groupsAsync.valueOrNull ?? [];
                          final items = _selectedTab == 'all'
                              ? ref.read(allUserItemsProvider).valueOrNull ?? []
                              : _selectedTab == 'personal'
                                  ? ref.read(personalItemsProvider).valueOrNull ?? []
                                  : ref.read(groupItemsProvider(_selectedTab)).valueOrNull ?? [];
                          _logMultipleAsExpense(items, groups);
                        },
                        icon: const Icon(Icons.add_card_rounded, color: Colors.white, size: 20),
                        label: Text(
                          'Log ${_selectedItemIds.length} ${_selectedItemIds.length == 1 ? 'Item' : 'Items'} as Expense',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
      floatingActionButton: _selectedItemIds.isEmpty
          ? Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FloatingActionButton(
                onPressed: () {
                  HapticHelper.lightTap();
                  final groups = groupsAsync.valueOrNull ?? [];
                  _showAddOptionsModal(context, groups);
                },
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 4,
                shape: const CircleBorder(),
                child: const Icon(Icons.add_rounded, size: 28),
              ),
            )
          : null,
    );
  }

  Widget _buildTabChip(String key, String label, IconData icon) {
    final isSelected = _selectedTab == key;

    return GestureDetector(
      onTap: () {
        HapticHelper.selectionClick();
        setState(() {
          _selectedTab = key;
          _selectedItemIds.clear();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(
    BuildContext context,
    GroupItem item,
    bool isOwner,
    Group? group,
    dynamic currentUser,
    List<GroupItem> allItems,
    List<Group> groups,
  ) {
    final isSelected = _selectedItemIds.contains(item.id);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: item.isBought
            ? AppColors.surfaceVariant.withValues(alpha: 0.5)
            : isSelected
                ? const Color(0xFF10B981).withValues(alpha: 0.08)
                : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF10B981)
              : item.isBought
                  ? AppColors.borderLight.withValues(alpha: 0.5)
                  : AppColors.borderLight,
          width: isSelected ? 1.5 : 1,
        ),
        boxShadow: item.isBought
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Checkbox toggle (mark as bought)
          GestureDetector(
            onTap: () async {
              if (currentUser == null) return;
              HapticHelper.mediumTap();
              await ref.read(itemsRepositoryProvider).toggleItemBought(
                    item: item,
                    user: currentUser,
                  );
              ref.invalidate(allUserItemsProvider);
              ref.invalidate(personalItemsProvider);
              if (!item.isPersonal) {
                ref.invalidate(groupItemsProvider(item.groupId));
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(top: 2, right: 12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: item.isBought ? const Color(0xFF10B981) : Colors.transparent,
                border: Border.all(
                  color: item.isBought
                      ? const Color(0xFF10B981)
                      : AppColors.textTertiary,
                  width: 2,
                ),
              ),
              child: item.isBought
                  ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                  : null,
            ),
          ),

          // Item Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: item.isBought
                              ? AppColors.textTertiary
                              : AppColors.textPrimary,
                          decoration:
                              item.isBought ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                    if (item.quantity.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: item.isBought
                              ? AppColors.surfaceVariant
                              : const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.quantity,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: item.isBought
                                ? AppColors.textTertiary
                                : const Color(0xFF10B981),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),

                // Meta row: group/personal tag + added by + bought by
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: item.isPersonal
                            ? const Color(0xFF10B981).withValues(alpha: 0.12)
                            : AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.isPersonal ? 'Personal' : (group?.name ?? (item.groupName.isNotEmpty ? item.groupName : 'Group')),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: item.isPersonal
                              ? const Color(0xFF10B981)
                              : AppColors.primary,
                        ),
                      ),
                    ),
                    Text(
                      '• Added by ${item.addedByName}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    if (item.isBought && item.boughtByName != null) ...[
                      Text(
                        '• Bought by ${item.boughtByName}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ],
                ),

                // Actions for Bought Items: Log as Expense & Multi-Select Checkbox
                if (item.isBought) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      // Single "Log as Expense" Button (Pre-fills description)
                      InkWell(
                        onTap: () {
                          final desc = item.quantity.isNotEmpty
                              ? '${item.title} (${item.quantity})'
                              : item.title;
                          Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute(
                              builder: (_) => AddExpenseScreen(
                                group: group,
                                initialDescription: desc,
                                initialDate: DateTime.now(),
                              ),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF10B981).withValues(alpha: 0.25),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_card_rounded, size: 14, color: Color(0xFF10B981)),
                              SizedBox(width: 6),
                              Text(
                                'Log as Expense',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Multi-Select Toggle Chip
                      InkWell(
                        onTap: () => _toggleItemSelection(item.id),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF10B981)
                                : AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                size: 14,
                                color: isSelected ? Colors.white : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isSelected ? 'Selected' : 'Select',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Delete Button (Available for item creator)
          if (isOwner)
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
              tooltip: 'Delete Item',
              onPressed: () async {
                await ref.read(itemsRepositoryProvider).deleteItem(item.id);
                setState(() => _selectedItemIds.remove(item.id));
                ref.invalidate(allUserItemsProvider);
                ref.invalidate(personalItemsProvider);
                if (!item.isPersonal) {
                  ref.invalidate(groupItemsProvider(item.groupId));
                }
              },
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.shopping_bag_outlined,
                  size: 48, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'Your Shopping Checklist is Empty',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add items you or your group need to buy.\nCheck them off when purchased and log them as expenses directly!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddOptionsModal(BuildContext context, List<Group> groups) {
    HapticHelper.lightTap();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Add Items To Buy',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Where would you like to add the shopping checklist?',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),

              // Personal Option
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: AppColors.borderLight),
                ),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.person_rounded, color: Color(0xFF10B981), size: 22),
                ),
                title: const Text('Personal Checklist', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                subtitle: Text('Private list visible only to you', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                trailing: Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(
                      builder: (_) => const AddItemScreen(group: null),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),

              // Groups Section
              if (groups.isNotEmpty) ...[
                Text(
                  'Group Checklists',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.4,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: groups.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final group = groups[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: AppColors.borderLight),
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.groups_rounded, color: AppColors.primary, size: 22),
                        ),
                        title: Text(group.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        subtitle: Text('Shared with all group members', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        trailing: Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute(
                              builder: (_) => AddItemScreen(group: group),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
