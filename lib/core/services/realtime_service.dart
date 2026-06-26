import 'dart:convert';
import 'package:appwrite/appwrite.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/constants/app_constants.dart';
import '../appwrite_client.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/calendar/presentation/calendar_page.dart';
import '../../features/expenses/data/expense_repository.dart';
import '../../features/expenses/domain/expense_model.dart';
import '../../features/notifications/data/notification_repository.dart';
import '../../features/notifications/domain/notification_model.dart';

class RealtimeService {
  final Realtime _realtime;
  final Ref _ref;
  RealtimeSubscription? _subscription;

  RealtimeService(this._realtime, this._ref);

  void startListening() {
    if (_subscription != null) return;

    final channels = [
      'databases.${AppConstants.databaseId}.collections.${AppConstants.expensesCollection}.documents',
      'databases.${AppConstants.databaseId}.collections.${AppConstants.notificationsCollection}.documents',
    ];

    try {
      _subscription = _realtime.subscribe(channels);
      
      _subscription!.stream.listen((event) {
        debugPrint('Realtime Event received on channels: ${event.channels}');
        
        final action = event.events.first; // e.g. "databases.expense_manager_db.collections.expenses.documents.xxx.create"
        
        // Safely parse event payload (on Web it might be a LegacyJavaScriptObject)
        final Map<String, dynamic> doc;
        if (kIsWeb) {
          Map<String, dynamic> parsedDoc;
          try {
            parsedDoc = Map<String, dynamic>.from(jsonDecode(jsonEncode(event.payload)));
          } catch (_) {
            parsedDoc = {};
          }
          doc = parsedDoc;
        } else {
          doc = event.payload;
        }

        if (event.channels.any((c) => c.contains(AppConstants.expensesCollection))) {
          try {
            if (action.endsWith('.delete')) {
              final id = doc['\$id'] as String;
              _ref.invalidate(userSplitsProvider);
              if (doc['expenseDate'] != null) {
                final expenseDate = DateTime.parse(doc['expenseDate'] as String);
                final monthKey = DateTime(expenseDate.year, expenseDate.month);
                _ref.read(monthlyExpensesProvider(monthKey).notifier).deleteExpense(id);
              } else {
                final currentMonth = _ref.read(calendarMonthProvider);
                _ref.invalidate(monthlyExpensesProvider(currentMonth));
              }
            } else {
              final expense = Expense.fromMap(doc);
              final expenseDate = expense.expenseDate;
              final monthKey = DateTime(expenseDate.year, expenseDate.month);
              final notifier = _ref.read(monthlyExpensesProvider(monthKey).notifier);
              
              if (action.endsWith('.create')) {
                notifier.addExpense(expense);
                if (expense.isGroup) {
                  _ref.invalidate(userSplitsProvider);
                }
              } else if (action.endsWith('.update')) {
                notifier.updateExpense(expense);
                if (expense.isGroup) {
                  _ref.invalidate(userSplitsProvider);
                }
              }
            }
          } catch (e) {
            debugPrint('Failed to process realtime expense event: $e');
            final currentMonth = _ref.read(calendarMonthProvider);
            _ref.invalidate(monthlyExpensesProvider(currentMonth));
            _ref.invalidate(userSplitsProvider);
          }
        }
        
        if (event.channels.any((c) => c.contains(AppConstants.notificationsCollection))) {
          try {
            final notification = NotificationModel.fromMap(doc);
            final notifier = _ref.read(notificationsProvider.notifier);
            
            if (action.endsWith('.create')) {
              notifier.addNotification(notification);
            } else if (action.endsWith('.update')) {
              notifier.updateNotification(notification);
            } else if (action.endsWith('.delete')) {
              notifier.deleteNotification(notification.id);
            }
          } catch (e) {
            debugPrint('Failed to process realtime notification event: $e');
            _ref.invalidate(notificationsProvider);
          }
        }
      });
      debugPrint('Started listening to Appwrite Realtime.');
    } catch (e) {
      debugPrint('Realtime subscription error: $e');
    }
  }

  void stopListening() {
    _subscription?.close();
    _subscription = null;
    debugPrint('Stopped listening to Appwrite Realtime.');
  }
}

final realtimeServiceProvider = Provider<RealtimeService>((ref) {
  final realtime = ref.watch(appwriteRealtimeProvider);
  final service = RealtimeService(realtime, ref);
  
  ref.onDispose(() {
    service.stopListening();
  });
  
  return service;
});

final realtimeInitProvider = Provider<void>((ref) {
  final service = ref.watch(realtimeServiceProvider);
  
  // Watch authentication state to restart/stop subscription reactively
  final authState = ref.watch(authStateProvider);
  authState.when(
    data: (user) {
      if (user != null) {
        // Stop any existing listener to guarantee clean connection context under the new session
        service.stopListening();
        service.startListening();
      } else {
        service.stopListening();
      }
    },
    loading: () {
      service.stopListening();
    },
    error: (_, __) {
      service.stopListening();
    },
  );
});
