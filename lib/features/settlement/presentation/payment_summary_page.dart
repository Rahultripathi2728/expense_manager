import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:appwrite/appwrite.dart';
import 'package:url_launcher/url_launcher.dart';
import 'settlement_page.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/constants/app_constants.dart';
import '../../../core/utils/date_helpers.dart';
import '../../../core/utils/row_helpers.dart';
import '../../../core/appwrite_client.dart';
import '../../auth/data/auth_repository.dart';
import '../../expenses/data/expense_repository.dart';
import '../../expenses/domain/expense_model.dart';
import '../../expenses/domain/expense_split_model.dart';
import '../../groups/data/group_repository.dart';
import '../../profile/domain/profile_model.dart';
import '../data/settlement_repository.dart';
import '../domain/balance_calculator.dart';

class PaymentSummaryPage extends ConsumerStatefulWidget {
  final String groupId;
  final List<Expense> selectedExpenses;

  const PaymentSummaryPage({
    super.key,
    required this.groupId,
    required this.selectedExpenses,
  });

  @override
  ConsumerState<PaymentSummaryPage> createState() => _PaymentSummaryPageState();
}

class _PaymentSummaryPageState extends ConsumerState<PaymentSummaryPage> {
  bool _isLoading = true;
  List<SimplifiedTransaction> _allTransactions = [];
  List<SimplifiedTransaction> _myTransactions = [];
  Map<String, Profile> _profiles = {};
  final Set<String> _settledTransactionKeys = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _calculateBalances();
  }

  Future<void> _calculateBalances() async {
    try {
      final repo = ref.read(expenseRepositoryProvider);
      final currentUser = ref.read(authStateProvider).valueOrNull;
      final myUserId = currentUser?.id ?? '';

      // Fetch splits for selected expenses
      final List<ExpenseSplit> allSplits = [];
      for (final exp in widget.selectedExpenses) {
        final splits = await repo.getExpenseSplits(exp.id);
        allSplits.addAll(splits);
      }

      // Fetch settlements
      final settlementsRepo = ref.read(settlementRepositoryProvider);
      final settlements = await settlementsRepo.getGroupSettlements(widget.groupId);

      // Fetch group members
      final members = await ref.read(groupRepositoryProvider).getGroupMembers(widget.groupId);
      final memberUserIds = members.map((m) => m.userId).toList();

      // Calculate balances using the exact same per-split calculation engine
      final calcResult = BalanceCalculator.calculateExpenseSplitBalances(
        expenses: widget.selectedExpenses,
        allSplits: allSplits,
        settlements: settlements,
        memberUserIds: memberUserIds,
      );

      final netBalances = calcResult.netBalances;
      final transactions = calcResult.transactions;

      // Fetch profiles
      final userIds = netBalances.keys.toList();
      if (userIds.isNotEmpty) {
        final tablesDB = ref.read(appwriteTablesDBProvider);
        final resProfiles = await tablesDB.listRows(
          databaseId: AppConstants.databaseId,
          tableId: AppConstants.profilesCollection,
          queries: [Query.equal('userId', userIds)],
        );
        final profilesList = resProfiles.rows.map((d) => Profile.fromMap(d.dataWithId)).toList();
        _profiles = {for (var p in profilesList) p.userId: p};
      }

      // Filter transactions where I am the payer (fromUserId == myUserId)
      final myTx = transactions.where((t) => t.fromUserId == myUserId).toList();

      setState(() {
        _allTransactions = transactions;
        _myTransactions = myTx;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _payViaUPI(SimplifiedTransaction tx, Profile? recipient) async {
    final toName = recipient?.fullName ?? 'Member';
    final upiId = recipient?.upiId ?? '';

    if (upiId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$toName has not set a UPI ID yet. Please ask them to add it in Profile settings.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final uri = Uri.parse(
      'upi://pay?pa=$upiId&pn=${Uri.encodeComponent(toName)}&am=${tx.amount.toStringAsFixed(2)}&cu=INR&tn=Settlement%20via%20SplitPro',
    );

    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open UPI payment app. Please make payment manually.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No UPI application found on device.')),
        );
      }
    }
  }

  Future<void> _settleSingleTransaction(SimplifiedTransaction tx) async {
    final key = '${tx.fromUserId}_${tx.toUserId}_${tx.amount}';
    if (_settledTransactionKeys.contains(key)) return;

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(settlementRepositoryProvider);
      final currentUser = ref.read(authStateProvider).valueOrNull;
      final expenseIds = widget.selectedExpenses.map((e) => e.id).toList();

      await repo.settleBalancesLocalFallback(
        widget.groupId,
        tx.fromUserId,
        tx.toUserId,
        tx.amount,
        expenseIds,
      );

      _settledTransactionKeys.add(key);

      // Send in-app notification to group & recipient
      final recipientName = _profiles[tx.toUserId]?.fullName ?? 'Member';
      final payerName = currentUser?.name.isNotEmpty == true ? currentUser!.name : 'Group Member';
      _notifySettlement(
        groupId: widget.groupId,
        payerName: payerName,
        recipientUserId: tx.toUserId,
        amount: tx.amount,
      );

      ref.invalidate(groupBalancesProvider(widget.groupId));
      ref.invalidate(monthlyExpensesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment of ₹${tx.amount.toStringAsFixed(0)} to $recipientName marked as settled!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error settling payment: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _settleAllMyPayments() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(settlementRepositoryProvider);
      final currentUser = ref.read(authStateProvider).valueOrNull;
      final expenseIds = widget.selectedExpenses.map((e) => e.id).toList();
      final payerName = currentUser?.name.isNotEmpty == true ? currentUser!.name : 'Group Member';

      for (final tx in _myTransactions) {
        final key = '${tx.fromUserId}_${tx.toUserId}_${tx.amount}';
        if (!_settledTransactionKeys.contains(key)) {
          await repo.settleBalancesLocalFallback(
            widget.groupId,
            tx.fromUserId,
            tx.toUserId,
            tx.amount,
            expenseIds,
          );
          _settledTransactionKeys.add(key);

          _notifySettlement(
            groupId: widget.groupId,
            payerName: payerName,
            recipientUserId: tx.toUserId,
            amount: tx.amount,
          );
        }
      }

      ref.invalidate(groupBalancesProvider(widget.groupId));
      ref.invalidate(monthlyExpensesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All your payments marked as settled! Your balance is now ₹0.'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _notifySettlement({
    required String groupId,
    required String payerName,
    required String recipientUserId,
    required double amount,
  }) async {
    try {
      final tablesDB = ref.read(appwriteTablesDBProvider);
      await tablesDB.createRow(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.notificationsCollection,
        rowId: ID.unique(),
        data: {
          'userId': recipientUserId,
          'title': '💰 Payment Received & Settled',
          'body': '$payerName marked ₹${amount.toStringAsFixed(0)} as paid and settled with you.',
          'type': 'settled',
          'isRead': false,
          'createdAt': DateTime.now().toIso8601String(),
        },
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authStateProvider).valueOrNull;
    final myUserId = currentUser?.id ?? '';
    final pendingMyTransactions = _myTransactions.where((t) {
      final key = '${t.fromUserId}_${t.toUserId}_${t.amount}';
      return !_settledTransactionKeys.contains(key);
    }).toList();

    final totalOwedByMe = pendingMyTransactions.fold<double>(0.0, (sum, t) => sum + t.amount);
    final otherTransactions = _allTransactions.where((t) => t.fromUserId != myUserId).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(
          'Pay & Settle Up',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.red)))
              : ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Header Summary Banner
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: totalOwedByMe > 0
                              ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                              : [const Color(0xFF10B981), const Color(0xFF059669)],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: (totalOwedByMe > 0
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFF10B981))
                                .withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                totalOwedByMe > 0
                                    ? Icons.pending_actions_rounded
                                    : Icons.check_circle_outline_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                totalOwedByMe > 0 ? 'Your Pending Dues' : 'You are All Settled Up!',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            DateHelpers.formatCurrency(totalOwedByMe),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            totalOwedByMe > 0
                                ? 'Pay your share to group members below to clear your balance.'
                                : 'You do not owe any money in this group.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Section 1: Payments You Need to Make
                    if (_myTransactions.isNotEmpty) ...[
                      Text(
                        'People You Need to Pay',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._myTransactions.map((tx) {
                        final toProfile = _profiles[tx.toUserId];
                        final toName = toProfile?.fullName ?? 'Member';
                        final upiId = toProfile?.upiId ?? '';
                        final key = '${tx.fromUserId}_${tx.toUserId}_${tx.amount}';
                        final isSettled = _settledTransactionKeys.contains(key);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSettled
                                  ? const Color(0xFF10B981).withValues(alpha: 0.4)
                                  : AppColors.borderLight,
                            ),
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
                                  // Recipient Avatar
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppColors.primary,
                                          const Color(0xFF60A5FA),
                                        ],
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        toName.isNotEmpty ? toName[0].toUpperCase() : 'M',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          toName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.qr_code_rounded,
                                              size: 13,
                                              color: upiId.isNotEmpty
                                                  ? AppColors.primary
                                                  : AppColors.textTertiary,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              upiId.isNotEmpty ? upiId : 'UPI ID not added',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: upiId.isNotEmpty
                                                    ? AppColors.textSecondary
                                                    : AppColors.textTertiary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        DateHelpers.formatCurrency(tx.amount),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 18,
                                          color: Color(0xFFEF4444),
                                        ),
                                      ),
                                      if (isSettled)
                                        Container(
                                          margin: const EdgeInsets.only(top: 4),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            'SETTLED ✅',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF10B981),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              // Actions Row (Pay via UPI + Mark Settled)
                              if (!isSettled)
                                Row(
                                  children: [
                                    // Pay via UPI Button
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => _payViaUPI(tx, toProfile),
                                        icon: const Icon(Icons.payment_rounded, size: 16),
                                        label: const Text('Pay via UPI'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppColors.primary,
                                          side: BorderSide(color: AppColors.primary),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),

                                    // Mark as Settled Button
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () => _settleSingleTransaction(tx),
                                        icon: const Icon(Icons.check_rounded, size: 16),
                                        label: const Text('Mark Settled'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF10B981),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          elevation: 0,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        );
                      }),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle_outline_rounded,
                                size: 28, color: Color(0xFF10B981)),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'You have no payments to make. All your expenses are balanced!',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Section 2: Other Group Transfers (Read-only reference)
                    if (otherTransactions.isNotEmpty) ...[
                      Text(
                        'Other Transfers in Group',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...otherTransactions.map((tx) {
                        final fromName = _profiles[tx.fromUserId]?.fullName ?? 'Member';
                        final toName = _profiles[tx.toUserId]?.fullName ?? 'Member';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    fromName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.grey),
                                  const SizedBox(width: 6),
                                  Text(
                                    toName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ],
                              ),
                              Text(
                                DateHelpers.formatCurrency(tx.amount),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
      bottomNavigationBar: pendingMyTransactions.isNotEmpty
          ? Container(
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
                child: ElevatedButton.icon(
                  onPressed: _settleAllMyPayments,
                  icon: const Icon(Icons.done_all_rounded, color: Colors.white),
                  label: Text(
                    'Mark All My Dues as Settled (${DateHelpers.formatCurrency(totalOwedByMe)})',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
            )
          : null,
    );
  }
}
