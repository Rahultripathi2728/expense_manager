import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/appwrite_client.dart';
import '../../../app/constants/app_constants.dart';
import '../../../core/utils/row_helpers.dart';
import '../domain/expense_model.dart';
import '../domain/expense_split_model.dart';
import '../../auth/data/auth_repository.dart';
import '../../groups/data/group_repository.dart';
import '../../../core/utils/date_helpers.dart';
import '../../../core/local_db/database_helper.dart';
import '../../../core/services/sync_service.dart';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sqflite/sqflite.dart';

class ExpenseRepository {
  final TablesDB _tablesDB;
  final SyncService _syncService;
  final DatabaseHelper _dbHelper;

  ExpenseRepository(this._tablesDB, this._syncService, this._dbHelper);

  Future<Expense> createPersonalExpense({
    required String userId,
    required String description,
    required double amount,
    required String category,
    required DateTime date,
  }) async {
    final expenseId = ID.unique();
    final data = {
      'userId': userId,
      'description': description,
      'amount': amount,
      'category': category,
      'expenseType': 'personal',
      'expenseDate': date.toIso8601String(),
      'createdAt': DateTime.now().toIso8601String(),
      'isSettled': true,
    };

    if (kIsWeb) {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none)) {
        throw Exception('No internet connection. Please connect to the internet to add an expense.');
      }
      final doc = await _tablesDB.createRow(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.expensesCollection,
        rowId: expenseId,
        data: data,
      );
      return Expense.fromMap(doc.dataWithId);
    } else {
      final expense = Expense.fromMap({'\$id': expenseId, ...data});

      // 1. Save to Local DB
      final db = await _dbHelper.database;
      await db.insert('expenses', {'id': expenseId, ...data});

      // 2. Queue for Sync
      await _syncService.queueAction('create', 'expenses', data, documentId: expenseId);

      return expense;
    }
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
    final expenseId = ID.unique();
    final expenseDate = (date ?? DateTime.now()).toIso8601String();
    final createdAt = DateTime.now().toIso8601String();
    
    final expenseData = {
      'userId': userId,
      'groupId': groupId,
      'description': description,
      'amount': amount,
      'category': category,
      'expenseType': 'group',
      'splitType': splitType,
      'expenseDate': expenseDate,
      'createdAt': createdAt,
      'isSettled': false,
    };

    if (kIsWeb) {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none)) {
        throw Exception('No internet connection. Please connect to the internet to add an expense.');
      }
      final doc = await _tablesDB.createRow(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.expensesCollection,
        rowId: expenseId,
        data: expenseData,
      );
      return Expense.fromMap(doc.dataWithId);
    } else {
      final expense = Expense.fromMap({'\$id': expenseId, ...expenseData});

      // 1. Save to Local DB
      final db = await _dbHelper.database;
      await db.insert('expenses', {'id': expenseId, ...expenseData});

      // 2. Queue the appwrite function payload
      // We queue a special action for group expenses to be handled by sync service
      // For now, to keep it simple, we will just call the function directly. If offline, it fails.
      // True offline group expenses with cloud functions is complex. We will queue it as a normal document creation.
      await _syncService.queueAction('create', 'expenses', expenseData, documentId: expenseId);

      return expense;
    }
  }

  Future<void> _syncExpensesFromRemote(String userId, DateTime month) async {
    try {
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

      final db = await _dbHelper.database;
      for (final doc in res.rows) {
        final data = doc.dataWithId;
        final id = data['\$id'];
        data.remove('\$id');
        data['id'] = id;
        
        // Remove nested/unsupported fields for SQLite
        data.remove('\$permissions');
        data.remove('\$collectionId');
        data.remove('\$databaseId');
        data.remove('\$createdAt');
        data.remove('\$updatedAt');

        await db.insert('expenses', data, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    } catch (e) {
      // Offline, ignore
    }
  }

  Future<List<Expense>> getExpensesForMonth(String userId, DateTime month) async {
    final start = DateHelpers.startOfMonth(month);
    final end = DateHelpers.endOfMonth(month);

    if (kIsWeb) {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none)) {
        throw Exception('No internet connection.');
      }
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
      return res.rows.map((doc) => Expense.fromMap(doc.dataWithId)).toList();
    } else {
      // 1. Trigger background sync
      _syncExpensesFromRemote(userId, month);

      // 2. Return local data
      final db = await _dbHelper.database;
      final res = await db.query(
        'expenses',
        where: 'userId = ? AND expenseDate >= ? AND expenseDate <= ?',
        whereArgs: [userId, start.toIso8601String(), end.toIso8601String()],
        orderBy: 'expenseDate DESC',
      );

      return res.map((map) {
        final m = Map<String, dynamic>.from(map);
        m['\$id'] = m['id'];
        m['isSettled'] = m['isSettled'] == 1; // SQLite bool conversion
        return Expense.fromMap(m);
      }).toList();
    }
  }

  Future<List<Expense>> getGroupExpenses(String groupId) async {
    if (kIsWeb) {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none)) {
        throw Exception('No internet connection.');
      }
      final res = await _tablesDB.listRows(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.expensesCollection,
        queries: [
          Query.equal('groupId', groupId),
          Query.orderDesc('expenseDate'),
          Query.limit(AppConstants.maxPageSize),
        ],
      );
      return res.rows.map((doc) => Expense.fromMap(doc.dataWithId)).toList();
    } else {
      try {
        final res = await _tablesDB.listRows(
          databaseId: AppConstants.databaseId,
          tableId: AppConstants.expensesCollection,
          queries: [
            Query.equal('groupId', groupId),
            Query.orderDesc('expenseDate'),
            Query.limit(AppConstants.maxPageSize),
          ],
        );
        final db = await _dbHelper.database;
        for (final doc in res.rows) {
          final data = doc.dataWithId;
          final id = data['\$id'];
          data.remove('\$id');
          data['id'] = id;
          data.remove('\$permissions');
          data.remove('\$collectionId');
          data.remove('\$databaseId');
          data.remove('\$createdAt');
          data.remove('\$updatedAt');
          await db.insert('expenses', data, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      } catch (e) {
        // Offline, continue
      }

      final db = await _dbHelper.database;
      final localRes = await db.query(
        'expenses',
        where: 'groupId = ?',
        whereArgs: [groupId],
        orderBy: 'expenseDate DESC',
      );

      return localRes.map((map) {
        final m = Map<String, dynamic>.from(map);
        m['\$id'] = m['id'];
        m['isSettled'] = m['isSettled'] == 1;
        return Expense.fromMap(m);
      }).toList();
    }
  }

  Future<List<ExpenseSplit>> getExpenseSplits(String expenseId) async {
    try {
      final res = await _tablesDB.listRows(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.expenseSplitsCollection,
        queries: [Query.equal('expenseId', expenseId)],
      );
      return res.rows.map((d) => ExpenseSplit.fromMap(d.dataWithId)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<ExpenseSplit>> getUserSplits(String userId) async {
    try {
      final res = await _tablesDB.listRows(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.expenseSplitsCollection,
        queries: [
          Query.equal('userId', userId),
          Query.limit(AppConstants.maxPageSize),
        ],
      );
      return res.rows.map((d) => ExpenseSplit.fromMap(d.dataWithId)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> deleteExpense(String expenseId) async {
    if (kIsWeb) {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none)) {
        throw Exception('No internet connection. Please connect to the internet to delete an expense.');
      }
      await _tablesDB.deleteRow(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.expensesCollection,
        rowId: expenseId,
      );
    } else {
      final db = await _dbHelper.database;
      await db.delete('expenses', where: 'id = ?', whereArgs: [expenseId]);
      await _syncService.queueAction('delete', 'expenses', null, documentId: expenseId);
    }
  }
}

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository(
    ref.watch(appwriteTablesDBProvider),
    ref.watch(syncServiceProvider),
    ref.watch(databaseHelperProvider),
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
    for (final g in groups) {
      final groupExps = await repo.getGroupExpenses(g.id);
      allGroupExpenses.addAll(
        groupExps.where((e) => DateHelpers.isSameMonth(e.expenseDate, month)),
      );
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
