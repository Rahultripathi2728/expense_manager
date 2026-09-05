import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../auth/data/auth_repository.dart';
import '../../groups/domain/group_model.dart';
import '../data/items_repository.dart';
import '../domain/group_item_model.dart';

class AddItemScreen extends ConsumerStatefulWidget {
  final Group? group; // If null, it's Personal
  const AddItemScreen({super.key, this.group});

  @override
  ConsumerState<AddItemScreen> createState() => _AddItemScreenState();
}

class _ItemRowControllers {
  final TextEditingController titleController;
  final TextEditingController qtyController;

  _ItemRowControllers()
      : titleController = TextEditingController(),
        qtyController = TextEditingController();

  void dispose() {
    titleController.dispose();
    qtyController.dispose();
  }
}

class _AddItemScreenState extends ConsumerState<AddItemScreen> {
  final List<_ItemRowControllers> _rows = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Start with 2 initial item rows
    _rows.add(_ItemRowControllers());
    _rows.add(_ItemRowControllers());
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  void _addNewRow() {
    HapticHelper.lightTap();
    setState(() {
      _rows.add(_ItemRowControllers());
    });
  }

  void _removeRow(int index) {
    HapticHelper.lightTap();
    if (_rows.length > 1) {
      setState(() {
        _rows[index].dispose();
        _rows.removeAt(index);
      });
    }
  }

  Future<void> _handleSave() async {
    final drafts = _rows
        .map((r) => ItemDraft(
              title: r.titleController.text.trim(),
              quantity: r.qtyController.text.trim(),
            ))
        .where((d) => d.title.isNotEmpty)
        .toList();

    if (drafts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter at least one item name')),
      );
      return;
    }

    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    setState(() => _isSaving = true);
    HapticHelper.mediumTap();

    try {
      final isPersonal = widget.group == null;
      await ref.read(itemsRepositoryProvider).addMultipleItems(
            groupId: isPersonal ? 'personal' : widget.group!.id,
            groupName: isPersonal ? 'Personal' : widget.group!.name,
            drafts: drafts,
            user: user,
          );

      // Invalidate relevant providers
      ref.invalidate(allUserItemsProvider);
      ref.invalidate(personalItemsProvider);
      if (!isPersonal) {
        ref.invalidate(groupItemsProvider(widget.group!.id));
      }

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${drafts.length} ${drafts.length == 1 ? 'item' : 'items'} added successfully!',
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding items: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPersonal = widget.group == null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Add Items to Buy',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: Column(
        children: [
          // Target Header Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.borderLight)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isPersonal
                        ? const Color(0xFF10B981).withValues(alpha: 0.15)
                        : AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isPersonal ? Icons.person_rounded : Icons.groups_rounded,
                    color: isPersonal ? const Color(0xFF10B981) : AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPersonal ? 'Personal Checklist' : widget.group!.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        isPersonal
                            ? 'Visible only to you'
                            : 'Shared with all group members',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Scrollable list of item rows
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                ...List.generate(_rows.length, (index) {
                  return _buildItemRow(index);
                }),
                const SizedBox(height: 12),

                // + Add Another Item button
                InkWell(
                  onTap: _addNewRow,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        style: BorderStyle.solid,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_circle_outline_rounded,
                            color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Add Another Item',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
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
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _handleSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
                      'Save Items to List',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemRow(int index) {
    final controllers = _rows[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Item #${index + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              if (_rows.length > 1)
                IconButton(
                  icon: Icon(Icons.remove_circle_outline_rounded,
                      size: 20, color: AppColors.error),
                  onPressed: () => _removeRow(index),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Remove',
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Title
          Text(
            'Item Name',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controllers.titleController,
            decoration: const InputDecoration(
              hintText: 'e.g. Milk 2L, Bread, Eggs, Dish Soap...',
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),

          // Quantity / Note
          Text(
            'Quantity / Note (Optional)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controllers.qtyController,
            decoration: const InputDecoration(
              hintText: 'e.g. 2 packets, 1kg, Amul, Brand XYZ...',
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
