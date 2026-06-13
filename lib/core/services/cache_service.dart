import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../features/expenses/domain/expense_model.dart';

/// Lightweight caching service to support offline-first reads for recent expenses.
class CacheService {
  final SharedPreferences _prefs;

  CacheService(this._prefs);

  static const _expensesKey = 'cached_expenses';

  /// Save recent expenses to cache.
  Future<void> cacheExpenses(List<Expense> expenses) async {
    // Only cache last 90 days to avoid huge payload
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(days: 90));

    final recent = expenses
        .where((e) => e.expenseDate.isAfter(cutoff))
        .toList();

    final jsonList = recent.map((e) => jsonEncode(e.toMap())).toList();
    await _prefs.setStringList(_expensesKey, jsonList);
  }

  /// Get cached expenses.
  List<Expense> getCachedExpenses() {
    final jsonList = _prefs.getStringList(_expensesKey);
    if (jsonList == null) return [];

    try {
      return jsonList.map((str) => Expense.fromMap(jsonDecode(str))).toList();
    } catch (_) {
      return [];
    }
  }

  /// Clear all cache.
  Future<void> clearCache() async {
    await _prefs.remove(_expensesKey);
  }
}

/// A provider that requires initialization in main.dart
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Initialize sharedPreferencesProvider in main.dart');
});

final cacheServiceProvider = Provider<CacheService>((ref) {
  return CacheService(ref.watch(sharedPreferencesProvider));
});
