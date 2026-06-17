import 'package:appwrite/appwrite.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/constants/app_constants.dart';
import '../appwrite_client.dart';
import '../../features/expenses/data/expense_repository.dart';
import '../../features/notifications/data/notification_repository.dart';

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
        
        if (event.channels.any((c) => c.contains(AppConstants.expensesCollection))) {
          // Invalidate expense providers so UI updates immediately
          _ref.invalidate(monthlyExpensesProvider);
        }
        
        if (event.channels.any((c) => c.contains(AppConstants.notificationsCollection))) {
          // Invalidate notifications provider
          _ref.invalidate(notificationsProvider);
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
  service.startListening();
});
