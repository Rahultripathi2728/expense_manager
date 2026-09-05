import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../features/expenses/domain/expense_model.dart';
import '../../features/items/domain/group_item_model.dart';

/// Lightweight caching service to support offline-first reads for expenses, budgets, and shopping items.
class CacheService {
  final SharedPreferences _prefs;

  CacheService(this._prefs);

  static const _expensesKey = 'cached_expenses';
  static const _monthlyBudgetsKey = 'monthly_budgets_map';
  static const _shoppingItemsKey = 'cached_shopping_items';

  // ── Expenses Cache ──
  Future<void> cacheExpenses(List<Expense> expenses) async {
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(days: 90));

    final recent = expenses
        .where((e) => e.expenseDate.isAfter(cutoff))
        .toList();

    final jsonList = recent.map((e) => jsonEncode(e.toMap())).toList();
    await _prefs.setStringList(_expensesKey, jsonList);
  }

  List<Expense> getCachedExpenses() {
    final jsonList = _prefs.getStringList(_expensesKey);
    if (jsonList == null) return [];

    try {
      return jsonList.map((str) => Expense.fromMap(jsonDecode(str))).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Monthly Budget History & Persistence ──
  Map<String, double> getMonthlyBudgetsMap() {
    final str = _prefs.getString(_monthlyBudgetsKey);
    if (str == null || str.isEmpty) return {};
    try {
      final decoded = jsonDecode(str) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, (v as num).toDouble()));
    } catch (_) {
      return {};
    }
  }

  Future<void> saveMonthlyBudget(String yearMonth, double budget) async {
    final map = getMonthlyBudgetsMap();
    map[yearMonth] = budget;
    await _prefs.setString(_monthlyBudgetsKey, jsonEncode(map));
  }

  double getMonthlyBudgetForMonth(String yearMonth, double defaultBudget) {
    final map = getMonthlyBudgetsMap();
    if (map.containsKey(yearMonth)) {
      return map[yearMonth]!;
    }
    // Find the most recent budget configured on or before this month
    final sortedKeys = map.keys.toList()..sort();
    String? latestKeyBefore;
    for (final key in sortedKeys) {
      if (key.compareTo(yearMonth) <= 0) {
        latestKeyBefore = key;
      }
    }
    if (latestKeyBefore != null) {
      return map[latestKeyBefore]!;
    }
    return defaultBudget;
  }

  // ── Shopping Items Cache ──
  List<GroupItem> getCachedShoppingItems() {
    final jsonList = _prefs.getStringList(_shoppingItemsKey);
    if (jsonList == null) return [];
    try {
      return jsonList.map((str) => GroupItem.fromMap(jsonDecode(str))).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> cacheShoppingItems(List<GroupItem> items) async {
    final jsonList = items.map((i) => jsonEncode(i.toMap())).toList();
    await _prefs.setStringList(_shoppingItemsKey, jsonList);
  }

  /// Clear all cache.
  Future<void> clearCache() async {
    await _prefs.remove(_expensesKey);
    await _prefs.remove(_monthlyBudgetsKey);
    await _prefs.remove(_shoppingItemsKey);
  }
}

/// A provider that requires initialization in main.dart
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Initialize sharedPreferencesProvider in main.dart');
});

final cacheServiceProvider = Provider<CacheService>((ref) {
  return CacheService(ref.watch(sharedPreferencesProvider));
});
