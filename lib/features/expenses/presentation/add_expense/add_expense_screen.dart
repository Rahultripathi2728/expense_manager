import 'package:flutter/material.dart';
import '../../../../core/utils/haptic_helper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:appwrite/appwrite.dart';
import '../utils/category_icon_helper.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/constants/app_constants.dart';
import '../../../../core/appwrite_client.dart';
import '../../../../core/utils/date_helpers.dart';
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
import 'widgets/unequal_split_sheet.dart';
import '../../../settlement/presentation/settlement_page.dart';
import '../../../groups/presentation/group_detail_page.dart';

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
  final String? initialDescription;
  final double? initialAmount;
  final String? initialCategory;
  final List<SingleBillState>? initialBills;

  const AddExpenseScreen({
    super.key,
    required this.group,
    this.existingExpense,
    this.initialDate,
    this.initialDescription,
    this.initialAmount,
    this.initialCategory,
    this.initialBills,
  });

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  late final TextEditingController _dateCtrl;
  DateTime _selectedDate = DateTime.now();
  int _lastSyncedBillIndex = -1;
  int _lastBillCount = -1;

  @override
  void initState() {
    super.initState();
    if (widget.existingExpense != null) {
      _selectedDate = widget.existingExpense!.expenseDate;
      _descCtrl.text = widget.existingExpense!.description;
      _amountCtrl.text = widget.existingExpense!.amount.toString();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(addExpenseProvider(widget.group?.id).notifier).initializeWithExpense(widget.existingExpense!);
      });
    } else if (widget.initialBills != null && widget.initialBills!.isNotEmpty) {
      if (widget.initialDate != null) {
        _selectedDate = widget.initialDate!;
      }
      final first = widget.initialBills!.first;
      _descCtrl.text = first.description;
      if (first.amount > 0) {
        _amountCtrl.text = first.amount % 1 == 0
            ? first.amount.toInt().toString()
            : first.amount.toStringAsFixed(2);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(addExpenseProvider(widget.group?.id).notifier).initializeWithBills(widget.initialBills!);
        }
      });
    } else {
      if (widget.initialDate != null) {
        _selectedDate = widget.initialDate!;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(addExpenseProvider(widget.group?.id).notifier).updateDate(_selectedDate);
        if (widget.initialDescription != null) {
          ref.read(addExpenseProvider(widget.group?.id).notifier).updateDescription(widget.initialDescription!);
          if (widget.initialCategory != null) {
            ref.read(addExpenseProvider(widget.group?.id).notifier).updateCategory(widget.initialCategory!);
          }
        }
        if (widget.initialAmount != null) {
          ref.read(addExpenseProvider(widget.group?.id).notifier).updateAmount(widget.initialAmount!);
        }
      });
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
      ref.read(addExpenseProvider(widget.group?.id).notifier).updateDate(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentProfileAsync = ref.watch(currentProfileProvider);
    final state = ref.watch(addExpenseProvider(widget.group?.id));

    // Sync TextControllers when active bill switches or bill count changes
    if (state.bills.isNotEmpty) {
      final safeIndex = state.activeBillIndex.clamp(0, state.bills.length - 1);
      if (safeIndex != _lastSyncedBillIndex || state.bills.length != _lastBillCount) {
        _lastSyncedBillIndex = safeIndex;
        _lastBillCount = state.bills.length;
        final currentBill = state.bills[safeIndex];

        if (_descCtrl.text != currentBill.description) {
          _descCtrl.text = currentBill.description;
        }

        final targetAmountText = currentBill.amount > 0
            ? (currentBill.amount % 1 == 0
                ? currentBill.amount.toInt().toString()
                : currentBill.amount.toStringAsFixed(2))
            : '';
        if (_amountCtrl.text != targetAmountText) {
          _amountCtrl.text = targetAmountText;
        }

        final billDate = currentBill.date ?? _selectedDate;
        _selectedDate = billDate;
        _dateCtrl.text = _formatDate(billDate);
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
        if (widget.group?.id != null) {
          ref.invalidate(groupBalancesProvider(widget.group!.id));
          ref.invalidate(groupAllExpensesProvider(widget.group!.id));
        }
        ref.invalidate(userSplitsProvider);
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
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: isMe
                                        ? [AppColors.primary, const Color(0xFF41A5FF)]
                                        : [
                                            [const Color(0xFF8B5CF6), const Color(0xFFC084FC)],
                                            [const Color(0xFFEC4899), const Color(0xFFF472B6)],
                                            [const Color(0xFF10B981), const Color(0xFF34D399)],
                                            [const Color(0xFFF59E0B), const Color(0xFFFBBF24)],
                                          ][prof.fullName.hashCode.abs() % 4],
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: (isMe ? AppColors.primary : const Color(0xFF8B5CF6)).withValues(alpha: 0.25),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    initials,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
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
                                ? AppColors.primary
                                : AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isActive
                                  ? AppColors.primary
                                  : AppColors.borderLight,
                              width: 1,
                            ),
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(alpha: 0.3),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
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
                                        ? AppColors.surface.withValues(alpha: 0.8)
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
                      notifier.addBill(date: _selectedDate);
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
                            Builder(
                              builder: (context) {
                                final isDerived = activeBill.splitType == 'itemwise' || activeBill.splitType == 'unequal';
                                // Keep controller in sync if derived
                                if (isDerived) {
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    if (_amountCtrl.text != activeBill.amount.toStringAsFixed(2) && activeBill.amount > 0) {
                                      _amountCtrl.text = activeBill.amount.toStringAsFixed(2);
                                    }
                                  });
                                }
                                
                                return TextField(
                                  controller: _amountCtrl,
                                  readOnly: isDerived,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                  decoration: InputDecoration(
                                    prefixText: '₹ ',
                                    prefixStyle: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                    hintText: '0.00',
                                    hintStyle: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.normal,
                                      color: AppColors.textTertiary,
                                    ),
                                    filled: isDerived,
                                    fillColor: isDerived ? AppColors.surfaceVariant.withValues(alpha: 0.3) : Colors.transparent,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  ),
                                  onChanged: (val) {
                                    if (!isDerived) {
                                      final amt = double.tryParse(val) ?? 0.0;
                                      notifier.updateAmount(amt);
                                    }
                                  },
                                );
                              }
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
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border, width: 1.0),
                      ),
                      child: Row(
                        children: [
                          activeBill.category.isNotEmpty
                              ? CategoryIconHelper.buildBadge(activeBill.category, size: 30, iconSize: 16)
                              : Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceVariant,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.category_rounded,
                                    color: AppColors.textTertiary,
                                    size: 16,
                                  ),
                                ),
                          const SizedBox(width: 10),
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
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderLight, width: 1),
                      ),
                      child: Row(
                        children: [
                          _splitTypeButton(
                            context,
                            'Equally',
                            'equal',
                            activeBill.splitType,
                            notifier,
                            profiles,
                            activeBill,
                          ),
                          _splitTypeButton(
                            context,
                            'Unequally',
                            'unequal',
                            activeBill.splitType,
                            notifier,
                            profiles,
                            activeBill,
                          ),
                          _splitTypeButton(
                            context,
                            'Item wise',
                            'itemwise',
                            activeBill.splitType,
                            notifier,
                            profiles,
                            activeBill,
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
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.borderLight, width: 1)),
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
              onPressed: state.isLoading
                  ? null
                  : () => _handleSubmit(context, state, activeBill, notifier),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
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
        ),
      ),
    );
  }

  Widget _splitTypeButton(
    BuildContext context,
    String label,
    String value,
    String currentValue,
    AddExpenseNotifier notifier,
    List<Profile> profiles,
    SingleBillState activeBill,
  ) {
    final isSelected = value == currentValue;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          notifier.updateSplitType(value);
          if (value == 'unequal') {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (ctx) => Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
                child: UnequalSplitSheet(
                  profiles: profiles,
                  totalAmount: activeBill.amount,
                  initialAmounts: activeBill.unequalAmounts,
                  onApply: (newAmounts) {
                    notifier.updateUnequalAmounts(newAmounts);
                  },
                ),
              ),
            );
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: isSelected ? Colors.white : AppColors.textSecondary,
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
    int? targetBillIndex,
    String? headerTitle,
    String? headerSubtitle,
    VoidCallback? onCategorySelected,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetInnerCtx, setSheetState) {
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
                          headerTitle ?? 'Select Category',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            if (targetBillIndex != null) {
                              notifier.setBillCategory(targetBillIndex, 'misc');
                            } else {
                              notifier.updateCategory('misc');
                            }
                            Navigator.pop(sheetInnerCtx);
                            onCategorySelected?.call();
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
                    if (headerSubtitle != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, color: Color(0xFFF59E0B), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                headerSubtitle,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
                        itemBuilder: (gridCtx, index) {
                          if (index == categoryOptions.length) {
                            return GestureDetector(
                              onTap: () {
                                Navigator.pop(sheetInnerCtx);
                                _showAddCustomCategoryDialog(
                                  context,
                                  notifier,
                                  targetBillIndex: targetBillIndex,
                                  onCategorySelected: onCategorySelected,
                                );
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
                          final catColor = AppColors.categoryColor(option.id);

                          return GestureDetector(
                            onTap: () {
                              if (targetBillIndex != null) {
                                notifier.setBillCategory(targetBillIndex, option.id);
                              } else {
                                notifier.updateCategory(option.id);
                              }
                              Navigator.pop(sheetInnerCtx);
                              onCategorySelected?.call();
                            },
                            child: Column(
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? catColor
                                        : catColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSelected
                                          ? catColor
                                          : catColor.withValues(alpha: 0.25),
                                      width: isSelected ? 2.0 : 1.2,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: catColor.withValues(alpha: 0.4),
                                              blurRadius: 10,
                                              offset: const Offset(0, 3),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Center(
                                    child: Icon(
                                      CategoryIconHelper.getIcon(option.id),
                                      color: isSelected
                                          ? Colors.white
                                          : catColor,
                                      size: 22,
                                    ),
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

  void _showAddCustomCategoryDialog(
    BuildContext context,
    AddExpenseNotifier notifier, {
    int? targetBillIndex,
    VoidCallback? onCategorySelected,
  }) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Add Custom Category'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'e.g. Rent, Books, Charity',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(
                'Cancel',
                style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.textPrimary,
                foregroundColor: AppColors.surface,
              ),
              onPressed: () {
                final val = ctrl.text.trim();
                if (val.isNotEmpty) {
                  if (targetBillIndex != null) {
                    notifier.setBillCategory(targetBillIndex, val);
                  } else {
                    notifier.updateCategory(val);
                  }
                  Navigator.pop(dialogCtx);
                  onCategorySelected?.call();
                }
              },
              child: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold)),
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
    // 1. Validate description and amount for each bill first
    for (int i = 0; i < state.bills.length; i++) {
      final bill = state.bills[i];
      if (bill.description.trim().isEmpty) {
        notifier.setActiveBillIndex(i);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please enter a description for Bill ${i + 1}', style: const TextStyle(color: Colors.white)),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      if (bill.amount <= 0.0) {
        notifier.setActiveBillIndex(i);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please enter an amount greater than 0 for Bill ${i + 1}', style: const TextStyle(color: Colors.white)),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    // 2. Check for missing categories across all bills
    final unassignedIndices = <int>[];
    for (int i = 0; i < state.bills.length; i++) {
      if (state.bills[i].category.trim().isEmpty) {
        unassignedIndices.add(i);
      }
    }

    if (unassignedIndices.isEmpty) {
      notifier.submitExpense(
        groupId: widget.group?.id,
        date: _selectedDate,
      );
    } else if (state.bills.length == 1) {
      // Single bill: Directly present category options. Once selected, user can review on the screen before manual submission!
      _showCategoryBottomSheet(
        context,
        state.bills.first.category,
        notifier,
        headerTitle: 'Select Category',
        headerSubtitle: 'You forgot to select a category. Pick one below, or tap Skip:',
        onCategorySelected: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Category updated. Please review your expense and tap Submit Expense.'),
              backgroundColor: AppColors.primary,
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      );
    } else {
      // Multiple bills: Present multi-bill choice dialog
      _showCategoryMissingDialog(context, notifier);
    }
  }

  void _showCategoryMissingDialog(
    BuildContext context,
    AddExpenseNotifier notifier,
  ) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (stCtx, setDialogState) {
            final bills = ref.read(addExpenseProvider(widget.group?.id)).bills;
            final unassignedIndices = <int>[];
            for (int i = 0; i < bills.length; i++) {
              if (bills[i].category.trim().isEmpty) {
                unassignedIndices.add(i);
              }
            }

            final allDone = unassignedIndices.isEmpty;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: AppColors.surface,
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.category_outlined,
                      color: Color(0xFFF59E0B),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      allDone ? 'Categories Selected' : 'Category Not Selected',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      allDone
                          ? 'All bills now have categories! Tap OK to review and submit.'
                          : 'Select a category for each bill below, or tap "Skip All":',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxHeight: 250,
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (int i = 0; i < bills.length; i++) ...[
                              if (bills[i].category.trim().isEmpty) ...[
                                Builder(
                                  builder: (_) {
                                    final bill = bills[i];
                                    final billDesc = bill.description.isNotEmpty ? bill.description : 'Bill ${i + 1}';
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: AppColors.borderLight),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Bill ${i + 1}: $billDesc',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13.5,
                                                    color: AppColors.textPrimary,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  DateHelpers.formatCurrency(bill.amount),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: AppColors.textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.surface,
                                              foregroundColor: AppColors.primary,
                                              elevation: 0,
                                              side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            onPressed: () {
                                              _showCategoryBottomSheet(
                                                context,
                                                bill.category,
                                                notifier,
                                                targetBillIndex: i,
                                                headerSubtitle: 'Select category for Bill ${i + 1} ($billDesc):',
                                                onCategorySelected: () {
                                                  setDialogState(() {});
                                                },
                                              );
                                            },
                                            child: const Text(
                                              'Select',
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                if (!allDone) ...[
                  TextButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: Text(
                      'Cancel',
                      style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      for (int i = 0; i < bills.length; i++) {
                        if (bills[i].category.trim().isEmpty) {
                          notifier.setBillCategory(i, 'misc');
                        }
                      }
                      Navigator.pop(dialogCtx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Categories updated. Please review your bills and tap Submit Expense.'),
                          backgroundColor: AppColors.primary,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: Text(
                      'Skip All',
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                    ),
                  ),
                ],
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(dialogCtx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Please review your bills and tap Submit Expense.'),
                        backgroundColor: AppColors.primary,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: const Text(
                    'OK',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
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
  CategoryOption(id: 'food', label: 'Food', icon: Icons.fastfood_rounded, color: Color(0xFFFF9800)),
  CategoryOption(id: 'groceries', label: 'Groceries', icon: Icons.shopping_basket_rounded, color: Color(0xFFE91E63)),
  CategoryOption(id: 'travel', label: 'Travel', icon: Icons.flight_takeoff_rounded, color: Color(0xFF29B6F6)),
  CategoryOption(id: 'stays', label: 'Stays', icon: Icons.apartment_rounded, color: Color(0xFF795548)),
  CategoryOption(id: 'bills', label: 'Bills', icon: Icons.receipt_long_rounded, color: Color(0xFF607D8B)),
  CategoryOption(id: 'subscription', label: 'Subscription', icon: Icons.smart_display_rounded, color: Color(0xFFAB47BC)),
  CategoryOption(id: 'shopping', label: 'Shopping', icon: Icons.local_mall_rounded, color: Color(0xFF26C6DA)),
  CategoryOption(id: 'gifts', label: 'Gifts', icon: Icons.card_giftcard_rounded, color: Color(0xFF7986CB)),
  CategoryOption(id: 'drinks', label: 'Drinks', icon: Icons.local_bar_rounded, color: Color(0xFFFF7043)),
  CategoryOption(id: 'fuel', label: 'Fuel', icon: Icons.local_gas_station_rounded, color: Color(0xFF66BB6A)),
  CategoryOption(id: 'udhaar', label: 'Udhaar(Debt)', icon: Icons.handshake_rounded, color: Color(0xFFEC407A)),
  CategoryOption(id: 'health', label: 'Health', icon: Icons.medical_services_rounded, color: Color(0xFFD4E157)),
  CategoryOption(id: 'entertainment', label: 'Entertainment', icon: Icons.attractions_rounded, color: Color(0xFF26A69A)),
  CategoryOption(id: 'misc', label: 'Misc.', icon: Icons.category_rounded, color: Color(0xFFB0BEC5)),
];
