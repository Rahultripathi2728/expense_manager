import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/appwrite_client.dart';
import '../../../app/constants/app_constants.dart';
import '../domain/expense_model.dart';
import '../domain/expense_split_model.dart';
import '../domain/expense_item_model.dart';
import '../../../core/utils/row_helpers.dart';
import '../../auth/data/auth_repository.dart';
import '../../groups/data/group_repository.dart';
import '../../../core/utils/date_helpers.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ExpenseRepository {
  final TablesDB _tablesDB;

  ExpenseRepository(this._tablesDB);

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

    // Prepare splits
    final preparedSplits = splits.map((s) {
      final splitId = ID.unique();
      return {
        'id': splitId,
        'expenseId': expenseId,
        'userId': s['userId'],
        'amountOwed': s['amountOwed'],
        'isIncluded': s['isIncluded'] ?? true,
      };
    }).toList();

    // Prepare items
    final preparedItems = (items ?? []).map((i) {
      final itemId = ID.unique();
      return {
        'id': itemId,
        'expenseId': expenseId,
        'itemName': i['itemName'],
        'itemAmount': i['itemAmount'],
        'participants': i['participants'],
      };
    }).toList();

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
    
    for (final split in preparedSplits) {
      final data = Map<String, dynamic>.from(split)..remove('id');
      await _tablesDB.createRow(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.expenseSplitsCollection,
        rowId: split['id'],
        data: data,
      );
    }
    for (final item in preparedItems) {
      final data = Map<String, dynamic>.from(item)..remove('id');
      await _tablesDB.createRow(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.expenseItemsCollection,
        rowId: item['id'],
        data: data,
      );
    }
    
    // Create notifications for other users
    String creatorName = 'A group member';
    try {
      final profileRes = await _tablesDB.listRows(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.profilesCollection,
        queries: [Query.equal('\$id', userId)],
      );
      if (profileRes.rows.isNotEmpty) {
        creatorName = profileRes.rows.first.data['name'] ?? 'A group member';
      }
    } catch (_) {}

    for (final split in preparedSplits) {
      if (split['userId'] != userId && split['isIncluded'] == true) {
        final notifId = ID.unique();
        await _tablesDB.createRow(
          databaseId: AppConstants.databaseId,
          tableId: AppConstants.notificationsCollection,
          rowId: notifId,
          data: {
            'userId': split['userId'],
            'type': 'expense_added',
            'title': 'New Group Expense',
            'body': '$creatorName added "$description" (${amount.toStringAsFixed(0)})',
            'isRead': false,
            'createdAt': createdAt,
          },
        );
      }
    }
    
    return Expense.fromMap(doc.dataWithId);
  }

  Future<Expense> updatePersonalExpense({
    required String expenseId,
    required String description,
    required double amount,
    required String category,
    DateTime? date,
  }) async {
    final expenseDate = (date ?? DateTime.now()).toIso8601String();
    
    final data = {
      'description': description,
      'amount': amount,
      'category': category,
      'expenseDate': expenseDate,
    };

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      throw Exception('No internet connection.');
    }
    
    final doc = await _tablesDB.updateRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.expensesCollection,
      rowId: expenseId,
      data: data,
    );
    return Expense.fromMap(doc.dataWithId);
  }

  Future<Expense> updateGroupExpense({
    required String expenseId,
    required String description,
    required double amount,
    required String category,
    required String splitType,
    required List<Map<String, dynamic>> splits,
    List<Map<String, dynamic>>? items,
    DateTime? date,
  }) async {
    final expenseDate = (date ?? DateTime.now()).toIso8601String();
    
    final expenseData = {
      'description': description,
      'amount': amount,
      'category': category,
      'splitType': splitType,
      'expenseDate': expenseDate,
    };

    // Prepare splits
    final preparedSplits = splits.map((s) {
      final splitId = ID.unique();
      return {
        'id': splitId,
        'expenseId': expenseId,
        'userId': s['userId'],
        'amountOwed': s['amountOwed'],
        'isIncluded': s['isIncluded'] ?? true,
      };
    }).toList();

    // Prepare items
    final preparedItems = (items ?? []).map((i) {
      final itemId = ID.unique();
      return {
        'id': itemId,
        'expenseId': expenseId,
        'itemName': i['itemName'],
        'itemAmount': i['itemAmount'],
        'participants': i['participants'],
      };
    }).toList();

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      throw Exception('No internet connection.');
    }
    
    final doc = await _tablesDB.updateRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.expensesCollection,
      rowId: expenseId,
      data: expenseData,
    );
    
    final existingSplits = await _tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.expenseSplitsCollection,
      queries: [Query.equal('expenseId', expenseId)],
    );
    for (final s in existingSplits.rows) {
      await _tablesDB.deleteRow(databaseId: AppConstants.databaseId, tableId: AppConstants.expenseSplitsCollection, rowId: s.$id);
    }
    for (final split in preparedSplits) {
      final data = Map<String, dynamic>.from(split)..remove('id');
      await _tablesDB.createRow(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.expenseSplitsCollection,
        rowId: split['id'],
        data: data,
      );
    }

    final existingItems = await _tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.expenseItemsCollection,
      queries: [Query.equal('expenseId', expenseId)],
    );
    for (final i in existingItems.rows) {
      await _tablesDB.deleteRow(databaseId: AppConstants.databaseId, tableId: AppConstants.expenseItemsCollection, rowId: i.$id);
    }
    for (final item in preparedItems) {
      final data = Map<String, dynamic>.from(item)..remove('id');
      await _tablesDB.createRow(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.expenseItemsCollection,
        rowId: item['id'],
        data: data,
      );
    }

    return Expense.fromMap(doc.dataWithId);
  }


  Future<List<Expense>> getExpensesForMonth(String userId, DateTime month) async {
    final start = DateHelpers.startOfMonth(month);
    final end = DateHelpers.endOfMonth(month);

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
  }

  Future<List<Expense>> getGroupExpenses(String groupId) async {
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

  Future<List<ExpenseItem>> getExpenseItems(String expenseId) async {
    try {
      final res = await _tablesDB.listRows(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.expenseItemsCollection,
        queries: [Query.equal('expenseId', expenseId)],
      );
      return res.rows.map((d) => ExpenseItem.fromMap(d.dataWithId)).toList();
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
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      throw Exception('No internet connection. Please connect to the internet to delete an expense.');
    }
    
    try {
      final existingSplits = await _tablesDB.listRows(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.expenseSplitsCollection,
        queries: [Query.equal('expenseId', expenseId)],
      );
      for (final s in existingSplits.rows) {
        await _tablesDB.deleteRow(databaseId: AppConstants.databaseId, tableId: AppConstants.expenseSplitsCollection, rowId: s.$id);
      }

      final existingItems = await _tablesDB.listRows(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.expenseItemsCollection,
        queries: [Query.equal('expenseId', expenseId)],
      );
      for (final i in existingItems.rows) {
        await _tablesDB.deleteRow(databaseId: AppConstants.databaseId, tableId: AppConstants.expenseItemsCollection, rowId: i.$id);
      }
    } catch (_) {}

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
