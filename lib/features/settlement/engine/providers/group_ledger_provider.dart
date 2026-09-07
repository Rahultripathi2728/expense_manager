import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/constants/app_constants.dart';
import '../../../../core/appwrite_client.dart';
import '../../../../core/utils/row_helpers.dart';
import '../../../expenses/data/expense_repository.dart';
import '../../../expenses/domain/expense_split_model.dart';
import '../../../groups/data/group_repository.dart';
import '../../../profile/domain/profile_model.dart';
import '../../data/settlement_repository.dart';
import '../models/group_ledger_state.dart';
import '../settlement_engine.dart';

/// Canonical Riverpod provider for the complete Group Ledger State.
/// Single source of truth for all screens displaying group balances, bills, debts, or settlement status.
final groupLedgerProvider = FutureProvider.family<GroupLedgerState, String>((ref, groupId) async {
  final groupRepo = ref.watch(groupRepositoryProvider);
  final expenseRepo = ref.watch(expenseRepositoryProvider);
  final settlementsRepo = ref.watch(settlementRepositoryProvider);

  // 1. Fetch group members
  final members = await groupRepo.getGroupMembers(groupId);
  final memberUserIds = members.map((m) => m.userId).toList();

  if (memberUserIds.isEmpty) {
    return GroupLedgerState.empty();
  }

  // 2. Fetch profiles for all members
  final tablesDB = ref.watch(appwriteTablesDBProvider);
  final resProfiles = await tablesDB.listRows(
    databaseId: AppConstants.databaseId,
    tableId: AppConstants.profilesCollection,
    queries: [Query.equal('userId', memberUserIds)],
  );
  final profiles = resProfiles.rows.map((d) => Profile.fromMap(d.dataWithId)).toList();
  final profileMap = {for (var p in profiles) p.userId: p};

  // 3. Fetch all expenses & settlements
  final allExpenses = await expenseRepo.getGroupExpenses(groupId);
  final settlements = await settlementsRepo.getGroupSettlements(groupId);

  // 4. Fetch all splits for active/all expenses
  final List<ExpenseSplit> allSplits = [];
  for (final exp in allExpenses) {
    try {
      final splits = await expenseRepo.getExpenseSplits(exp.id);
      allSplits.addAll(splits);
    } catch (_) {
      // Split loading fallback: ignored
    }
  }

  // 5. Compute deterministic ledger using SettlementEngine
  return SettlementEngine.computeLedger(
    memberUserIds: memberUserIds,
    expenses: allExpenses,
    allSplits: allSplits,
    settlements: settlements,
    profiles: profileMap,
  );
});
