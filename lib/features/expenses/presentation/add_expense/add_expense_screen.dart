import 'package:flutter/material.dart';
import '../../../../core/utils/haptic_helper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:appwrite/appwrite.dart';
import '../utils/category_icon_helper.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/constants/app_constants.dart';
import '../../../../core/appwrite_client.dart';
import '../../../../core/utils/row_helpers.dart';
import '../../../groups/domain/group_model.dart';
import '../../../groups/data/group_repository.dart';
import '../../../profile/domain/profile_model.dart';
import '../../../profile/data/profile_repository.dart';
import '../../../auth/data/auth_repository.dart';
import '../../domain/expense_model.dart';
import '../../data/expense_repository.dart';
import 'providers/add_expense_provider.dart';
import '../../../../shared/services/categorize_service.dart';
import '../../../../shared/widgets/dashed_rect_painter.dart';
import 'widgets/split_sections.dart';
final groupProfilesProvider = FutureProvider.autoDispose
    .family<List<Profile>, String>((ref, groupId) async {
      final repo = ref.watch(groupRepositoryProvider);
      final members = await repo.getGroupMembers(groupId);
      if (members.isEmpty) return [];

      final userIds = members.map((m) => m.userId).toList();
      final tablesDB = ref.watch(appwriteTablesDBProvider);

      final futures = userIds.map((id) async {
        try {
          return await tablesDB.listRows(
            databaseId: AppConstants.databaseId,
            tableId: AppConstants.profilesCollection,
            queries: [Query.equal('userId', id)],
          );
        } catch (_) {
          return null;
        }
      });

      final results = await Future.wait(futures);
      final profiles = <Profile>[];

      for (int i = 0; i < userIds.length; i++) {
        final res = results[i];
        if (res != null && res.rows.isNotEmpty) {
          profiles.add(Profile.fromMap(res.rows.first.dataWithId));
        } else {
          profiles.add(
            Profile(
              id: userIds[i],
              userId: userIds[i],
              fullName: 'Group Member',
              createdAt: DateTime.now(),
            ),
          );
        }
      }

      return profiles;
    });

class AddExpenseScreen extends ConsumerStatefulWidget {
  final Group? group;
  final Expense? existingExpense;
  final DateTime? initialDate;

  const AddExpenseScreen({super.key, required this.group, this.existingExpense, this.initialDate});

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  late final TextEditingController _dateCtrl;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.existingExpense != null) {
      _selectedDate = widget.existingExpense!.expenseDate;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(addExpenseProvider(widget.group?.id).notifier).initializeWithExpense(widget.existingExpense!);
      });
    } else if (widget.initialDate != null) {
      _selectedDate = widget.initialDate!;
    }
    _dateCtrl = TextEditingController(text: _formatDate(_selectedDate));
  }

  String _formatDate(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}";

  @override
  void dispose() {
    _descCtrl.dispose();
    _amountCtrl.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.textPrimary,
              onPrimary: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: AppColors.textPrimary),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateCtrl.text = _formatDate(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentProfileAsync = ref.watch(currentProfileProvider);
    final state = ref.watch(addExpenseProvider(widget.group?.id));

    // Sync TextControllers when active bill switches
    if (state.bills.isNotEmpty && state.activeBillIndex < state.bills.length) {
      final activeBill = state.bills[state.activeBillIndex];
      if (_descCtrl.text != activeBill.description) {
        _descCtrl.text = activeBill.description;
      }
      final currentAmount = double.tryParse(_amountCtrl.text) ?? 0.0;
      if (currentAmount != activeBill.amount) {
        _amountCtrl.text = activeBill.amount > 0.0
            ? activeBill.amount.toStringAsFixed(2)
            : '';
      }
    }

    if (widget.group != null) {
      final profilesAsync = ref.watch(groupProfilesProvider(widget.group!.id));

      return profilesAsync.when(
        data: (profiles) {
          return _buildContent(context, profiles);
        },
        loading: () => Scaffold(
          backgroundColor: AppColors.surface,
          body: Center(child: CircularProgressIndicator(color: AppColors.textPrimary)),
        ),
        error: (err, _) => Scaffold(
          backgroundColor: AppColors.surface,
          body: Center(
            child: Text(
              'Error: $err',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ),
      );
    } else {
      return currentProfileAsync.when(
        data: (profile) {
          final profiles = profile != null ? [profile] : <Profile>[];
          return _buildContent(context, profiles);
        },
        loading: () => Scaffold(
          backgroundColor: AppColors.surface,
          body: Center(child: CircularProgressIndicator(color: AppColors.textPrimary)),
        ),
        error: (err, _) => Scaffold(
          backgroundColor: AppColors.surface,
          body: Center(
            child: Text(
              'Error: $err',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ),
      );
    }
  }

  Widget _buildContent(BuildContext context, List<Profile> profiles) {
    final state = ref.watch(addExpenseProvider(widget.group?.id));
    final notifier = ref.read(addExpenseProvider(widget.group?.id).notifier);

    // Listen for success state to pop screen
    ref.listen<AddExpenseState>(addExpenseProvider(widget.group?.id), (
      prev,
      next,
    ) {
      if (next.success) {
        HapticHelper.mediumTap();
        ref.invalidate(monthlyExpensesProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existingExpense != null ? 'Expense updated successfully!' : 'Expense added successfully!',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
      if (next.errorMessage != null &&
          next.errorMessage != prev?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              next.errorMessage!,
              style: TextStyle(color: AppColors.surface),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    });

    final currentUser = ref.read(authStateProvider).valueOrNull;
    final activeBill = state.bills.isNotEmpty
        ? state.bills[state.activeBillIndex]
        : SingleBillState();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(
          widget.existingExpense != null ? 'Edit Expense' : 'Add Expense',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (widget.group != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.group!.name,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Members row
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 85,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: profiles.length,
                      itemBuilder: (context, index) {
                        final prof = profiles[index];
                        final isMe = prof.userId == currentUser?.id;

                        // Extract initials
                        final parts = prof.fullName.trim().split(' ');
                        String initials = 'U';
                        if (parts.isNotEmpty) {
                          if (parts.length > 1) {
                            initials = (parts[0][0] + parts[1][0])
                                .toUpperCase();
                          } else if (parts[0].isNotEmpty) {
                            initials = parts[0][0].toUpperCase();
                          }
                        }
                        if (isMe) initials = 'Y';

                        return Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: Column(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.borderLight,
                                    width: 1,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 24,
                                  backgroundColor: const Color(0xFFF3F3F3),
                                  child: Text(
                                    initials,
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                isMe
                                    ? '${prof.fullName.split(' ').first} (You)'
                                    : prof.fullName.split(' ').first,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Dynamic bill toggles row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  ...List.generate(state.bills.length, (index) {
                    final isActive = index == state.activeBillIndex;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => notifier.setActiveBillIndex(index),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppColors.textPrimary
                                : const Color(0xFFF3F3F3),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isActive
                                  ? AppColors.textPrimary
                                  : AppColors.border,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Bill ${index + 1}',
                                style: TextStyle(
                                  color: isActive ? AppColors.surface : AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              if (state.bills.length > 1) ...[
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () {
                                    notifier.removeBill(index);
                                  },
                                  child: Icon(
                                    Icons.close,
                                    size: 14,
                                    color: isActive
                                        ? AppColors.textSecondary
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      notifier.addBill();
                    },
                    child: CustomPaint(
                      painter: DashedRectPainter(
                        color: AppColors.textTertiary,
                        strokeWidth: 1.0,
                        gap: 4.0,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, size: 14, color: AppColors.textPrimary),
                            const SizedBox(width: 4),
                            Text(
                              'Add bill',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Form card container
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderLight, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Description Label & Field
                  Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _descCtrl,
                    maxLines: null,
                    decoration: const InputDecoration(
                      hintText: 'What did you buy?',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    onChanged: notifier.updateDescription,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Price & Date side-by-side
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Price Column
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Price (₹)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _amountCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                hintText: '0.00',
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                              ),
                              onChanged: (val) {
                                final amt = double.tryParse(val) ?? 0.0;
                                notifier.updateAmount(amt);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Date Column
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Date',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: () => _selectDate(context),
                              child: AbsorbPointer(
                                child: TextFormField(
                                  decoration: InputDecoration(
                                    suffixIcon: Icon(
                                      Icons.calendar_today_outlined,
                                      size: 16,
                                      color: AppColors.textPrimary,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                  ),
                                  controller: _dateCtrl,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Category Label & Field
                  Text(
                    'Category',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => _showCategoryBottomSheet(context, activeBill.category, notifier),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border, width: 1.0),
                      ),
                      child: Row(
                        children: [
                          activeBill.category.isNotEmpty
                              ? Icon(
                                  CategoryIconHelper.getIcon(activeBill.category),
                                  color: AppColors.textPrimary,
                                  size: 20,
                                )
                              : Icon(
                                  Icons.tag_outlined,
                                  color: AppColors.textTertiary,
                                  size: 20,
                                ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              activeBill.category.isNotEmpty
                                  ? CategorizeService.displayName(activeBill.category)
                                  : 'Select Category',
                              style: TextStyle(
                                fontSize: 14,
                                color: activeBill.category.isNotEmpty
                                    ? AppColors.textPrimary
                                    : AppColors.textTertiary,
                                fontWeight: activeBill.category.isNotEmpty
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.keyboard_arrow_down,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Split section (only for groups)
                  if (widget.group != null) ...[
                    Text(
                      'Split',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Custom toggle buttons
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F3F3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          _splitTypeButton(
                            'Equally',
                            'equal',
                            activeBill.splitType,
                            notifier,
                          ),
                          _splitTypeButton(
                            'Unequally',
                            'unequal',
                            activeBill.splitType,
                            notifier,
                          ),
                          _splitTypeButton(
                            'Item wise',
                            'itemwise',
                            activeBill.splitType,
                            notifier,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Render corresponding split details
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOutCubic,
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: double.infinity,
                        child: activeBill.splitType == 'equal'
                            ? EquallySplitWidget(profiles: profiles, activeBill: activeBill, notifier: notifier)
                            : activeBill.splitType == 'unequal'
                            ? UnequallySplitWidget(profiles: profiles, activeBill: activeBill, notifier: notifier)
                            : activeBill.splitType == 'itemwise'
                            ? ItemwiseSplitWidget(profiles: profiles, activeBill: activeBill, notifier: notifier)
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Action/Submit Row
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: state.isLoading
                    ? null
                    : () => _handleSubmit(context, state, activeBill, notifier),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.textPrimary,
                  foregroundColor: AppColors.surface,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: state.isLoading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: AppColors.surface,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        widget.existingExpense != null ? 'Update expense' : 'Submit expense',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _splitTypeButton(
    String label,
    String value,
    String currentValue,
    AddExpenseNotifier notifier,
  ) {
    final isSelected = value == currentValue;
    return Expanded(
      child: GestureDetector(
        onTap: () => notifier.updateSplitType(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.textPrimary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: isSelected ? AppColors.surface : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  void _showCategoryBottomSheet(
    BuildContext context,
    String currentCategory,
    AddExpenseNotifier notifier, {
    bool isFromSubmit = false,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Select Category',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            notifier.updateCategory('misc');
                            Navigator.pop(context);
                            if (isFromSubmit) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                notifier.submitExpense(
                                  groupId: widget.group?.id,
                                  date: _selectedDate,
                                );
                              });
                            }
                          },
                          child: Text(
                            'Skip',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: GridView.builder(
                        shrinkWrap: true,
                        itemCount: categoryOptions.length + 1,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          childAspectRatio: 0.82,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 16,
                        ),
                        itemBuilder: (context, index) {
                          if (index == categoryOptions.length) {
                            return GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                                _showAddCustomCategoryDialog(context, notifier);
                              },
                              child: Column(
                                children: [
                                  Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: Colors.blueAccent.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.add,
                                      color: Colors.blueAccent,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      'Add Custom',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          final option = categoryOptions[index];
                          final isSelected = currentCategory.toLowerCase() == option.id;

                          return GestureDetector(
                            onTap: () {
                              notifier.updateCategory(option.id);
                              Navigator.pop(context);
                            },
                            child: Column(
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.textPrimary
                                        : AppColors.surfaceVariant,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.textPrimary
                                          : AppColors.border,
                                      width: isSelected ? 2.0 : 1.0,
                                    ),
                                  ),
                                  child: Icon(
                                    option.icon,
                                    color: isSelected
                                        ? AppColors.onPrimary
                                        : AppColors.textPrimary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    option.label,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? AppColors.textPrimary
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddCustomCategoryDialog(BuildContext context, AddExpenseNotifier notifier) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Custom Category'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'e.g. Rent, Books, Charity',
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.textPrimary,
                      foregroundColor: AppColors.surface,
                    ),
                    onPressed: () {
                      final val = ctrl.text.trim();
                      if (val.isNotEmpty) {
                        notifier.updateCategory(val);
                        Navigator.pop(context);
                      }
                    },
                    child: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _handleSubmit(
    BuildContext context,
    AddExpenseState state,
    SingleBillState activeBill,
    AddExpenseNotifier notifier,
  ) {
    if (activeBill.category.isEmpty) {
      _showCategoryBottomSheet(context, activeBill.category, notifier, isFromSubmit: true);
    } else {
      notifier.submitExpense(
        groupId: widget.group?.id,
        date: _selectedDate,
      );
    }
  }

}

class CategoryOption {
  final String id;
  final String label;
  final IconData icon;
  final Color color;

  const CategoryOption({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
  });
}

const List<CategoryOption> categoryOptions = [
  CategoryOption(id: 'food', label: 'Food', icon: Icons.restaurant, color: Color(0xFFFFB74D)),
  CategoryOption(id: 'groceries', label: 'Groceries', icon: Icons.shopping_basket_outlined, color: Color(0xFFF48FB1)),
  CategoryOption(id: 'travel', label: 'Travel', icon: Icons.card_travel, color: Color(0xFF4FC3F7)),
  CategoryOption(id: 'stays', label: 'Stays', icon: Icons.hotel_outlined, color: Color(0xFFA1887F)),
  CategoryOption(id: 'bills', label: 'Bills', icon: Icons.receipt_outlined, color: Color(0xFF90A4AE)),
  CategoryOption(id: 'subscription', label: 'Subscription', icon: Icons.subscriptions_outlined, color: Color(0xFFBA68C8)),
  CategoryOption(id: 'shopping', label: 'Shopping', icon: Icons.shopping_cart_outlined, color: Color(0xFF4DD0E1)),
  CategoryOption(id: 'gifts', label: 'Gifts', icon: Icons.card_giftcard_outlined, color: Color(0xFF9FA8DA)),
  CategoryOption(id: 'drinks', label: 'Drinks', icon: Icons.local_drink_outlined, color: Color(0xFFFF8A65)),
  CategoryOption(id: 'fuel', label: 'Fuel', icon: Icons.local_gas_station_outlined, color: Color(0xFF81C784)),
  CategoryOption(id: 'udhaar', label: 'Udhaar(Debt)', icon: Icons.pie_chart_outline, color: Color(0xFFF06292)),
  CategoryOption(id: 'health', label: 'Health', icon: Icons.favorite_border, color: Color(0xFFD4E157)),
  CategoryOption(id: 'entertainment', label: 'Entertainment', icon: Icons.confirmation_number_outlined, color: Color(0xFF4DB6AC)),
  CategoryOption(id: 'misc', label: 'Misc.', icon: Icons.more_horiz, color: Color(0xFFB0BEC5)),
];
