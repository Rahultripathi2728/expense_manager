import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:appwrite/appwrite.dart';
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
import '../../data/expense_repository.dart';
import 'providers/add_expense_provider.dart';
import '../../../../shared/services/categorize_service.dart';

final groupProfilesProvider = FutureProvider.autoDispose
    .family<List<Profile>, String>((ref, groupId) async {
      final repo = ref.watch(groupRepositoryProvider);
      final members = await repo.getGroupMembers(groupId);
      if (members.isEmpty) return [];

      final userIds = members.map((m) => m.userId).toList();
      final tablesDB = ref.watch(appwriteTablesDBProvider);

      final futures = userIds.map(
        (id) => tablesDB.listRows(
          databaseId: AppConstants.databaseId,
          tableId: AppConstants.profilesCollection,
          queries: [Query.equal('userId', id)],
        ),
      );

      final results = await Future.wait(futures);
      final profiles = <Profile>[];

      for (int i = 0; i < userIds.length; i++) {
        final res = results[i];
        if (res.rows.isNotEmpty) {
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

  const AddExpenseScreen({super.key, required this.group});

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
        ref.invalidate(monthlyExpensesProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Expense added successfully!'),
            backgroundColor: AppColors.textPrimary,
          ),
        );
        Navigator.pop(context);
      }
      if (next.errorMessage != null &&
          next.errorMessage != prev?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
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
          'Add Expense',
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
                  DropdownButtonFormField<String>(
                    initialValue: activeBill.category,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    items: CategorizeService.allCategories.map((cat) {
                      return DropdownMenuItem(
                        value: cat,
                        child: Text(CategorizeService.displayName(cat)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) notifier.updateCategory(val);
                    },
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
                            ? _buildEquallySplit(profiles, activeBill, notifier)
                            : activeBill.splitType == 'unequal'
                            ? _buildUnequallySplit(
                                profiles,
                                activeBill,
                                notifier,
                              )
                            : activeBill.splitType == 'itemwise'
                            ? _buildItemwiseSplit(
                                profiles,
                                activeBill,
                                notifier,
                              )
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
                    : () => notifier.submitExpense(
                        groupId: widget.group?.id,
                        date: _selectedDate,
                      ),
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
                    : const Text(
                        'Submit expense',
                        style: TextStyle(
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

  // --- EQUALLY SPLIT ---
  Widget _buildEquallySplit(
    List<Profile> profiles,
    SingleBillState activeBill,
    AddExpenseNotifier notifier,
  ) {
    final share = activeBill.selectedMemberIds.isNotEmpty
        ? activeBill.amount / activeBill.selectedMemberIds.length
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Split among (Tap to unselect)',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            TextButton(
              onPressed: notifier.selectAllMembers,
              child: Text(
                'Select All',
                style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: profiles.map((prof) {
            final isSelected = activeBill.selectedMemberIds.contains(
              prof.userId,
            );
            return GestureDetector(
              onTap: () => notifier.toggleMember(prof.userId),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.textPrimary.withValues(alpha: 0.04)
                      : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? AppColors.textPrimary : AppColors.borderLight,
                    width: 1.2,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      prof.fullName.split(' ').first,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${isSelected ? share.toStringAsFixed(0) : '0'}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? AppColors.textPrimary
                            : AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // --- UNEQUALLY SPLIT ---
  Widget _buildUnequallySplit(
    List<Profile> profiles,
    SingleBillState activeBill,
    AddExpenseNotifier notifier,
  ) {
    double totalUnequal = 0.0;
    for (final amt in activeBill.unequalAmounts.values) {
      totalUnequal += amt;
    }

    final diff = activeBill.amount - totalUnequal;
    final isMatching = diff.abs() < 0.01;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isMatching
                  ? 'All splits match total'
                  : diff > 0
                  ? 'Remaining: ₹${diff.toStringAsFixed(2)}'
                  : 'Overallocated: ₹${(-diff).toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isMatching ? const Color(0xFF22C55E) : AppColors.error,
              ),
            ),
            OutlinedButton(
              onPressed: notifier.splitUnequallyEqually,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(110, 30),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                side: BorderSide(color: AppColors.border),
              ),
              child: Text(
                'Split All Equally',
                style: TextStyle(fontSize: 11, color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: profiles.length,
          itemBuilder: (context, index) {
            final prof = profiles[index];
            final currentVal = activeBill.unequalAmounts[prof.userId] ?? 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFFF3F3F3),
                    child: Text(
                      prof.fullName.substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      prof.fullName,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    height: 38,
                    child: TextField(
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(
                        prefixText: '₹',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                      ),
                      controller:
                          TextEditingController(
                              text: currentVal > 0.0
                                  ? currentVal.toStringAsFixed(2)
                                  : '',
                            )
                            ..selection = TextSelection.collapsed(
                              offset: currentVal > 0.0
                                  ? currentVal.toStringAsFixed(2).length
                                  : 0,
                            ),
                      onChanged: (val) {
                        final amt = double.tryParse(val) ?? 0.0;
                        notifier.updateUnequalAmount(prof.userId, amt);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // --- ITEMWISE SPLIT ---
  Widget _buildItemwiseSplit(
    List<Profile> profiles,
    SingleBillState activeBill,
    AddExpenseNotifier notifier,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Items list',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ...activeBill.items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final itemTotal = item.price * item.qty;

          return Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: const Color(0xFFF9F9F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Item description...',
                          labelText: 'Description',
                        ),
                        onChanged: (val) =>
                            notifier.updateItemDescription(index, val),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: AppColors.error),
                      onPressed: () => notifier.removeItem(index),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    // Qty Controls
                    Row(
                      children: [
                        Text(
                          'Qty: ',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.remove_circle_outline,
                            size: 18,
                          ),
                          onPressed: () =>
                              notifier.updateItemQty(index, item.qty - 1),
                        ),
                        Text(
                          '${item.qty}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, size: 18),
                          onPressed: () =>
                              notifier.updateItemQty(index, item.qty + 1),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      'Total: ₹${itemTotal.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                // Price Field
                TextField(
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Price per item',
                    prefixText: '₹',
                  ),
                  onChanged: (val) {
                    final price = double.tryParse(val) ?? 0.0;
                    notifier.updateItemPrice(index, price);
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                // Split Among section for the item
                Text(
                  'Split Among (Tap names)',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    GestureDetector(
                      onTap: () {
                        for (final p in profiles) {
                          if (!item.participantIds.contains(p.userId)) {
                            notifier.toggleItemParticipant(index, p.userId);
                          }
                        }
                      },
                      child: Chip(
                        label: const Text(
                          'Equally',
                          style: TextStyle(fontSize: 10),
                        ),
                        backgroundColor:
                            item.participantIds.length == profiles.length
                            ? AppColors.textPrimary.withValues(alpha: 0.05)
                            : Colors.transparent,
                        side: BorderSide(color: AppColors.borderLight),
                      ),
                    ),
                    ...profiles.map((p) {
                      final isIncluded = item.participantIds.contains(p.userId);
                      return GestureDetector(
                        onTap: () =>
                            notifier.toggleItemParticipant(index, p.userId),
                        child: Chip(
                          label: Text(
                            p.fullName.split(' ').first,
                            style: const TextStyle(fontSize: 10),
                          ),
                          backgroundColor: isIncluded
                              ? AppColors.textPrimary.withValues(alpha: 0.05)
                              : Colors.transparent,
                          side: BorderSide(
                            color: isIncluded
                                ? AppColors.textPrimary
                                : AppColors.borderLight,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: notifier.addItem,
          icon: Icon(Icons.add, color: AppColors.textPrimary, size: 16),
          label: Text(
            'Add more item',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }
}

class DashedRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;

  DashedRectPainter({
    required this.color,
    required this.strokeWidth,
    required this.gap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final Path path = Path();
    path.addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(18),
      ),
    );

    const double dashWidth = 6.0;
    const double dashGap = 4.0;

    final Path dashedPath = Path();
    for (final PathMetric metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        const double len = dashWidth;
        if (distance + len > metric.length) {
          dashedPath.addPath(
            metric.extractPath(distance, metric.length),
            Offset.zero,
          );
        } else {
          dashedPath.addPath(
            metric.extractPath(distance, distance + len),
            Offset.zero,
          );
        }
        distance += len + dashGap;
      }
    }

    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(DashedRectPainter oldDelegate) =>
      color != oldDelegate.color ||
      strokeWidth != oldDelegate.strokeWidth ||
      gap != oldDelegate.gap;
}
