import 'dart:convert';
import 'package:appwrite/appwrite.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/constants/app_constants.dart';
import '../appwrite_client.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/expenses/data/expense_repository.dart';
import '../../features/expenses/domain/expense_model.dart';
import '../../features/notifications/data/notification_repository.dart';
import '../../features/notifications/domain/notification_model.dart';
import '../../features/groups/data/group_repository.dart';
import '../../features/groups/presentation/group_detail_page.dart';
import '../../features/settlement/data/settlement_repository.dart';
import '../../features/settlement/presentation/settlement_page.dart';
import '../../features/calendar/presentation/widgets/calendar_expense_card.dart';

class RealtimeService {
  final Realtime _realtime;
  final Ref _ref;
  RealtimeSubscription? _subscription;

  RealtimeService(this._realtime, this._ref);

  void startListening() {
    if (_subscription != null) return;

    final channels = [
      'databases.${AppConstants.databaseId}.collections.${AppConstants.expensesCollection}.documents',
      'databases.${AppConstants.databaseId}.collections.${AppConstants.settlementsCollection}.documents',
      'databases.${AppConstants.databaseId}.collections.${AppConstants.expenseSplitsCollection}.documents',
      'databases.${AppConstants.databaseId}.collections.${AppConstants.notificationsCollection}.documents',
      'databases.${AppConstants.databaseId}.collections.${AppConstants.groupsCollection}.documents',
      'databases.${AppConstants.databaseId}.collections.${AppConstants.groupMembersCollection}.documents',
    ];

    try {
      _subscription = _realtime.subscribe(channels);
      
      _subscription!.stream.listen((event) {
        debugPrint('Realtime Event received on channels: ${event.channels}');
        
        final action = event.events.first; // e.g. "...documents.xxx.create"
        
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

        // ── Expense Event ──
        if (event.channels.any((c) => c.contains(AppConstants.expensesCollection))) {
          try {
            final groupId = doc['groupId'] as String?;
            final id = doc['\$id'] as String? ?? '';

            // Real-time invalidation of all related expense & balance providers across app
            _ref.invalidate(userSplitsProvider);
            _ref.invalidate(monthlyExpensesProvider);
            _ref.invalidate(monthlyExpenseItemsProvider);
            _ref.invalidate(userCashFlowProvider);

            if (groupId != null && groupId.isNotEmpty) {
              _ref.invalidate(groupBalancesProvider(groupId));
              _ref.invalidate(groupAllExpensesProvider(groupId));
            }

            if (action.endsWith('.delete')) {
              if (doc['expenseDate'] != null) {
                final expenseDate = DateTime.parse(doc['expenseDate'] as String);
                final monthKey = DateTime(expenseDate.year, expenseDate.month);
                _ref.read(monthlyExpensesProvider(monthKey).notifier).deleteExpense(id);
              }
            } else {
              final expense = Expense.fromMap(doc);
              final expenseDate = expense.expenseDate;
              final monthKey = DateTime(expenseDate.year, expenseDate.month);
              final notifier = _ref.read(monthlyExpensesProvider(monthKey).notifier);
              
              if (action.endsWith('.create')) {
                notifier.addExpense(expense);
              } else if (action.endsWith('.update')) {
                notifier.updateExpense(expense);
              }
            }
          } catch (e) {
            debugPrint('Failed to process realtime expense event: $e');
            _ref.invalidate(monthlyExpensesProvider);
            _ref.invalidate(userSplitsProvider);
            _ref.invalidate(userCashFlowProvider);
          }
        }

        // ── Settlement Event ──
        if (event.channels.any((c) => c.contains(AppConstants.settlementsCollection))) {
          try {
            final groupId = doc['groupId'] as String?;
            if (groupId != null && groupId.isNotEmpty) {
              _ref.invalidate(groupBalancesProvider(groupId));
              _ref.invalidate(groupAllExpensesProvider(groupId));
            }
            _ref.invalidate(monthlyExpensesProvider);
            _ref.invalidate(userSplitsProvider);
            _ref.invalidate(userCashFlowProvider);
            debugPrint('Realtime settlement processed. Invalidate all balances and expense views.');
          } catch (e) {
            debugPrint('Failed to process realtime settlement event: $e');
          }
        }

        // ── Expense Splits Event ──
        if (event.channels.any((c) => c.contains(AppConstants.expenseSplitsCollection))) {
          try {
            final expenseId = doc['expenseId'] as String?;
            if (expenseId != null && expenseId.isNotEmpty) {
              _ref.invalidate(expenseSplitsProvider(expenseId));
            }
            _ref.invalidate(userSplitsProvider);
            _ref.invalidate(monthlyExpensesProvider);
          } catch (e) {
            debugPrint('Failed to process realtime split event: $e');
          }
        }

        // ── Groups / Members Event ──
        if (event.channels.any((c) => c.contains(AppConstants.groupsCollection) || c.contains(AppConstants.groupMembersCollection))) {
          try {
            _ref.invalidate(userGroupsProvider);
          } catch (_) {}
        }
        
        // ── Notification Event ──
        if (event.channels.any((c) => c.contains(AppConstants.notificationsCollection))) {
          try {
            final notification = NotificationModel.fromMap(doc);
            final currentUserId = _ref.read(authStateProvider).valueOrNull?.id;
            if (currentUserId != null && notification.userId != currentUserId) {
              // Notification is for another user, ignore
              return;
            }
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
      debugPrint('Started listening to Appwrite Realtime on all collections.');
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
