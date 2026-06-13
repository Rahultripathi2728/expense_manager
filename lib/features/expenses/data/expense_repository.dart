import 'dart:convert';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/enums.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/appwrite_client.dart';
import '../../../app/constants/app_constants.dart';
import '../../../core/utils/row_helpers.dart';
import '../domain/expense_model.dart';
import '../domain/expense_split_model.dart';
import '../../auth/data/auth_repository.dart';
import '../../groups/data/group_repository.dart';
import '../../../core/utils/date_helpers.dart';

class ExpenseRepository {
  final TablesDB _tablesDB;
  final Functions _functions;

  ExpenseRepository(this._tablesDB, this._functions);

  Future<Expense> createPersonalExpense({
    required String userId,
    required String description,
    required double amount,
    required String category,
    required DateTime date,
  }) async {
    final res = await _tablesDB.createRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.expensesCollection,
      rowId: ID.unique(),
      data: {
        'userId': userId,
        'description': description,
        'amount': amount,
        'category': category,
        'expenseType': 'personal',
        'expenseDate': date.toIso8601String(),
        'createdAt': DateTime.now().toIso8601String(),
        'isSettled': true, // Personal expenses don't need settlement
      },
    );
    return Expense.fromMap(res.dataWithId);
  }

  Future<Expense> createGroupExpense({
    required String groupId,
    required String userId,
    required String description,
    required double amount,
    required String category,
    required String splitType,
    required List<Map<String, dynamic>> splits,
    List<Map<String, dynamic>>? items,
    DateTime? date,
  }) async {
    final payload = {
      'expense': {
        'groupId': groupId,
        'userId': userId,
        'description': description,
        'amount': amount,
        'category': category,
        'expenseType': 'group',
        'splitType': splitType,
        'expenseDate': (date ?? DateTime.now()).toIso8601String(),
        'createdAt': DateTime.now().toIso8601String(),
      },
      'splits': splits,
      if (items != null) 'items': items,
    };

    try {
      final res = await _functions.createExecution(
        functionId: AppConstants.createGroupExpenseFunction,
        body: jsonEncode(payload),
      );

      if (res.status == ExecutionStatus.failed) {
        throw Exception(
          res.errors.isNotEmpty ? res.errors : 'Failed to create group expense',
        );
      }

      final responseMap = jsonDecode(res.responseBody);
      return Expense.fromMap(responseMap);
    } on AppwriteException catch (e) {
      // Only fallback for function-related errors (not deployed, timeout, etc.)
      // Auth or permission errors should propagate.
      if (e.code != null && e.code! >= 400 && e.code! < 500 && e.code != 404) {
        rethrow;
      }
      final expenseId = ID.unique();
      final expenseData = {
        'userId': userId,
        'groupId': groupId,
        'description': description,
        'amount': amount,
        'category': category,
        'expenseType': 'group',
        'splitType': splitType,
        'expenseDate': (date ?? DateTime.now()).toIso8601String(),
        'createdAt': DateTime.now().toIso8601String(),
        'isSettled': false,
      };

      final expDoc = await _tablesDB.createRow(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.expensesCollection,
        rowId: expenseId,
        data: expenseData,
      );

      // Create splits
      for (final split in splits) {
        await _tablesDB.createRow(
          databaseId: AppConstants.databaseId,
          tableId: AppConstants.expenseSplitsCollection,
          rowId: ID.unique(),
          data: {
            'expenseId': expenseId,
            'userId': split['userId'],
            'amountOwed': (split['amountOwed'] as num).toDouble(),
            'isIncluded': split['isIncluded'] ?? true,
          },
        );
      }

      // Create items if any
      if (items != null) {
        for (final item in items) {
          await _tablesDB.createRow(
            databaseId: AppConstants.databaseId,
            tableId: AppConstants.expenseItemsCollection,
            rowId: ID.unique(),
            data: {
              'expenseId': expenseId,
              'itemName': item['itemName'],
              'itemAmount': (item['itemAmount'] as num).toDouble(),
              'participants': List<String>.from(item['participants']),
            },
          );
        }
      }

      return Expense.fromMap(expDoc.dataWithId);
    }
  }

  Future<List<Expense>> getExpensesForMonth(
    String userId,
    DateTime month,
  ) async {
    final start = DateHelpers.startOfMonth(month);
    final end = DateHelpers.endOfMonth(month);

    final res = await _tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.expensesCollection,
      queries: [
        Query.equal('userId', userId),
        Query.greaterThanEqual('expenseDate', start.toIso8601String()),
        Query.lessThanEqual('expenseDate', end.toIso8601String()),
        Query.orderDesc('expenseDate'),
        Query.limit(AppConstants.maxPageSize),
      ],
    );

    return res.rows.map((d) => Expense.fromMap(d.dataWithId)).toList();
  }

  Future<List<Expense>> getGroupExpenses(String groupId) async {
    final res = await _tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.expensesCollection,
      queries: [
        Query.equal('groupId', groupId),
        Query.orderDesc('expenseDate'),
        Query.limit(AppConstants.maxPageSize),
      ],
    );
    return res.rows.map((d) => Expense.fromMap(d.dataWithId)).toList();
  }

  Future<List<ExpenseSplit>> getExpenseSplits(String expenseId) async {
    final res = await _tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.expenseSplitsCollection,
      queries: [Query.equal('expenseId', expenseId)],
    );
    return res.rows.map((d) => ExpenseSplit.fromMap(d.dataWithId)).toList();
  }

  Future<List<ExpenseSplit>> getUserSplits(String userId) async {
    final res = await _tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.expenseSplitsCollection,
      queries: [
        Query.equal('userId', userId),
        Query.limit(AppConstants.maxPageSize),
      ],
    );
    return res.rows.map((d) => ExpenseSplit.fromMap(d.dataWithId)).toList();
  }

  Future<void> deleteExpense(String expenseId) async {
    // 1. Delete associated splits
    final res = await _tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.expenseSplitsCollection,
      queries: [Query.equal('expenseId', expenseId)],
    );
    for (final doc in res.rows) {
      await _tablesDB.deleteRow(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.expenseSplitsCollection,
        rowId: doc.dataWithId['\$id'],
      );
    }

    // 2. Delete the expense itself
    await _tablesDB.deleteRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.expensesCollection,
      rowId: expenseId,
    );
  }
}

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository(
    ref.watch(appwriteTablesDBProvider),
    ref.watch(appwriteFunctionsProvider),
  );
});

final monthlyExpensesProvider = FutureProvider.family<List<Expense>, DateTime>((
  ref,
  month,
) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return [];

  final repo = ref.watch(expenseRepositoryProvider);
  final created = await repo.getExpensesForMonth(user.id, month);

  final groupsAsync = ref.watch(userGroupsProvider);
  final groups = groupsAsync.valueOrNull ?? [];

  final List<Expense> allGroupExpenses = [];
  
  if (groups.isNotEmpty) {
    // Fetch all group expenses in parallel
    final groupFutures = groups.map((g) async {
      try {
        final groupExps = await repo.getGroupExpenses(g.id);
        return groupExps
            .where((e) => DateHelpers.isSameMonth(e.expenseDate, month))
            .toList();
      } catch (_) {
        return <Expense>[];
      }
    });

    final results = await Future.wait(groupFutures);
    for (final monthExps in results) {
      allGroupExpenses.addAll(monthExps);
    }
  }

  final Map<String, Expense> merged = {};
  for (final e in created) {
    merged[e.id] = e;
  }
  for (final e in allGroupExpenses) {
    merged[e.id] = e;
  }

  return merged.values.toList();
});

final userSplitsProvider = FutureProvider<List<ExpenseSplit>>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return [];
  return ref.watch(expenseRepositoryProvider).getUserSplits(user.id);
});
