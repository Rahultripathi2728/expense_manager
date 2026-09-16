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
import '../../features/settlement/engine/providers/group_ledger_provider.dart';
import '../../features/calendar/presentation/widgets/calendar_expense_card.dart';
import '../../features/items/data/items_repository.dart';
import '../../features/items/domain/group_item_model.dart';
import 'cache_service.dart';

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
      'databases.${AppConstants.databaseId}.collections.${AppConstants.listsCollection}.documents',
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
            final paidBy = doc['paidBy'] as String?;
            final currentUserId = _ref.read(authStateProvider).valueOrNull?.id;

            if (currentUserId == null) return;

            final isPersonal = groupId == null || groupId.isEmpty;

            // Strict privacy check:
            // 1. Personal expense belongs ONLY to the user who created/paid it.
            //    If another user created a personal expense, ignore it completely.
            if (isPersonal && paidBy != null && paidBy != currentUserId) {
              return;
            }

            // 2. Group expense belongs ONLY to members of that group.
            if (!isPersonal && groupId.isNotEmpty) {
              final userGroups = _ref.read(userGroupsProvider).valueOrNull;
              if (userGroups != null && !userGroups.any((g) => g.id == groupId)) {
                return;
              }
            }

            DateTime? monthKey;
            if (doc['expenseDate'] != null) {
              final parsed = DateTime.tryParse(doc['expenseDate'] as String);
              if (parsed != null) {
                monthKey = DateTime(parsed.year, parsed.month);
              }
            }
            final now = DateTime.now();
            final currentMonthKey = DateTime(now.year, now.month);

            // Real-time invalidation of all related expense & balance providers across app
            _ref.invalidate(userSplitsProvider);
            if (monthKey != null) {
              _ref.invalidate(monthlyExpensesProvider(monthKey));
              _ref.invalidate(monthlyExpenseItemsProvider(monthKey));
              _ref.invalidate(userCashFlowProvider(monthKey));
            }
            _ref.invalidate(monthlyExpensesProvider(currentMonthKey));
            _ref.invalidate(userCashFlowProvider(currentMonthKey));

            if (groupId != null && groupId.isNotEmpty) {
              _ref.invalidate(groupLedgerProvider(groupId));
              _ref.invalidate(groupBalancesProvider(groupId));
              _ref.invalidate(groupAllExpensesProvider(groupId));
            }

            if (action.endsWith('.delete')) {
              if (paidBy != null && isPersonal && paidBy != currentUserId) {
                return;
              }
              if (monthKey != null) {
                _ref.read(monthlyExpensesProvider(monthKey).notifier).deleteExpense(id);
              }
            } else {
              final expense = Expense.fromMap(doc);
              final targetMonthKey = monthKey ?? DateTime(expense.expenseDate.year, expense.expenseDate.month);
              final notifier = _ref.read(monthlyExpensesProvider(targetMonthKey).notifier);
              
              if (action.endsWith('.create')) {
                notifier.addExpense(expense);
              } else if (action.endsWith('.update')) {
                notifier.updateExpense(expense);
              }
            }
          } catch (e) {
            debugPrint('Failed to process realtime expense event: $e');
          }
        }

        // ── Settlement Event ──
        if (event.channels.any((c) => c.contains(AppConstants.settlementsCollection))) {
          try {
            final groupId = doc['groupId'] as String?;
            final currentUserId = _ref.read(authStateProvider).valueOrNull?.id;
            if (currentUserId == null) return;

            if (groupId != null && groupId.isNotEmpty) {
              final userGroups = _ref.read(userGroupsProvider).valueOrNull;
              if (userGroups != null && !userGroups.any((g) => g.id == groupId)) {
                return;
              }
              _ref.invalidate(groupLedgerProvider(groupId));
              _ref.invalidate(groupBalancesProvider(groupId));
              _ref.invalidate(groupAllExpensesProvider(groupId));
            }
            final now = DateTime.now();
            final currentMonthKey = DateTime(now.year, now.month);
            _ref.invalidate(monthlyExpensesProvider(currentMonthKey));
            _ref.invalidate(userSplitsProvider);
            _ref.invalidate(userCashFlowProvider(currentMonthKey));
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
            final now = DateTime.now();
            final currentMonthKey = DateTime(now.year, now.month);
            _ref.invalidate(userSplitsProvider);
            _ref.invalidate(monthlyExpensesProvider(currentMonthKey));
            _ref.invalidate(userCashFlowProvider(currentMonthKey));
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
            if (currentUserId == null || notification.userId != currentUserId) {
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

        // ── Shopping / Group Items Event ──
        if (event.channels.any((c) => c.contains(AppConstants.listsCollection))) {
          try {
            final id = doc['\$id'] as String? ?? doc['id'] as String? ?? '';
            final groupId = doc['groupId'] as String?;
            final createdBy = doc['createdBy'] as String? ?? doc['userId'] as String?;
            final currentUserId = _ref.read(authStateProvider).valueOrNull?.id;
            final isPersonal = groupId == null || groupId.isEmpty || groupId == 'personal';

            if (currentUserId == null) return;

            // If personal item created by another user, ignore!
            if (isPersonal && createdBy != null && createdBy != currentUserId) {
              return;
            }

            // If group item and current user is not a member of the group, ignore!
            if (!isPersonal && groupId.isNotEmpty) {
              final userGroups = _ref.read(userGroupsProvider).valueOrNull;
              if (userGroups != null && !userGroups.any((g) => g.id == groupId)) {
                return;
              }
            }

            final cacheService = _ref.read(cacheServiceProvider);
            final cached = cacheService.getCachedShoppingItems();

            final cachedItem = cached.where((i) => i.id == id).firstOrNull;
            final effectiveGroupId = (doc['groupId'] as String?) ?? cachedItem?.groupId;

            if (action.endsWith('.delete')) {
              final updated = cached.where((i) => i.id != id).toList();
              cacheService.cacheShoppingItems(updated);
            } else {
              final item = GroupItem.fromMap(doc);
              final existingIndex = cached.indexWhere((i) => i.id == id);
              final List<GroupItem> updated;
              if (existingIndex >= 0) {
                updated = [...cached]..[existingIndex] = item;
              } else {
                updated = [item, ...cached];
              }
              cacheService.cacheShoppingItems(updated);
            }

            _ref.invalidate(allUserItemsProvider);
            _ref.invalidate(personalItemsProvider);
            if (effectiveGroupId != null && effectiveGroupId.isNotEmpty && effectiveGroupId != 'personal') {
              _ref.invalidate(groupItemsProvider(effectiveGroupId));
            }
          } catch (e) {
            debugPrint('Failed to process realtime list item event: $e');
            _ref.invalidate(allUserItemsProvider);
            _ref.invalidate(personalItemsProvider);
          }
        }
      }, onError: (error) {
        debugPrint('Appwrite Realtime stream error: $error');
      }, cancelOnError: false);
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
