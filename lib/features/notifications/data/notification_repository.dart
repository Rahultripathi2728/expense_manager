import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/appwrite_client.dart';
import '../../../app/constants/app_constants.dart';
import '../../../core/utils/row_helpers.dart';
import '../domain/notification_model.dart';
import '../../auth/data/auth_repository.dart';

class NotificationRepository {
  final TablesDB _tablesDB;

  NotificationRepository(this._tablesDB);

  Future<List<NotificationModel>> getNotifications(String userId) async {
    final res = await _tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.notificationsCollection,
      queries: [
        Query.equal('userId', userId),
        Query.orderDesc('createdAt'),
        Query.limit(50),
      ],
    );
    return res.rows
        .map((d) => NotificationModel.fromMap(d.dataWithId))
        .toList();
  }

  Future<void> markAsRead(String notificationId) async {
    await _tablesDB.updateRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.notificationsCollection,
      rowId: notificationId,
      data: {'isRead': true},
    );
  }

  Future<void> markAllAsRead(String userId) async {
    final res = await _tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.notificationsCollection,
      queries: [Query.equal('userId', userId), Query.equal('isRead', false)],
    );
    if (res.rows.isEmpty) return;
    await Future.wait(
      res.rows.map((doc) => markAsRead(doc.$id)),
    );
  }

  Future<void> clearAll(String userId) async {
    final res = await _tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.notificationsCollection,
      queries: [Query.equal('userId', userId)],
    );
    if (res.rows.isEmpty) return;
    await Future.wait(
      res.rows.map(
        (doc) => _tablesDB.deleteRow(
          databaseId: AppConstants.databaseId,
          tableId: AppConstants.notificationsCollection,
          rowId: doc.$id,
        ),
      ),
    );
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.watch(appwriteTablesDBProvider));
});

class NotificationsNotifier extends AsyncNotifier<List<NotificationModel>> {
  @override
  Future<List<NotificationModel>> build() async {
    final user = ref.watch(authStateProvider).valueOrNull;
    if (user == null) return [];
    return ref.watch(notificationRepositoryProvider).getNotifications(user.id);
  }

  void addNotification(NotificationModel notification) {
    if (state.hasValue) {
      final list = state.value!;
      if (list.any((n) => n.id == notification.id)) return;
      state = AsyncValue.data([notification, ...list]);
    }
  }

  void updateNotification(NotificationModel notification) {
    if (state.hasValue) {
      final list = state.value!;
      state = AsyncValue.data([
        for (final n in list)
          if (n.id == notification.id) notification else n
      ]);
    }
  }

  void deleteNotification(String id) {
    if (state.hasValue) {
      final list = state.value!;
      state = AsyncValue.data(
        list.where((n) => n.id != id).toList()
      );
    }
  }

  Future<void> markAllNotificationsAsRead() async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    // Optimistic UI Update
    final oldList = state.valueOrNull ?? [];
    state = AsyncValue.data(
      oldList.map((n) => n.copyWith(isRead: true)).toList(),
    );

    try {
      await ref.read(notificationRepositoryProvider).markAllAsRead(user.id);
    } catch (_) {
      // Fallback on error
      ref.invalidateSelf();
    }
  }

  Future<void> clearAllNotifications() async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    // Optimistic UI Update
    state = const AsyncValue.data([]);

    try {
      await ref.read(notificationRepositoryProvider).clearAll(user.id);
    } catch (_) {
      // Fallback on error
      ref.invalidateSelf();
    }
  }

  Future<void> markNotificationAsRead(String id) async {
    // Optimistic UI Update
    if (state.hasValue) {
      final list = state.value!;
      state = AsyncValue.data([
        for (final n in list)
          if (n.id == id) n.copyWith(isRead: true) else n
      ]);
    }

    try {
      await ref.read(notificationRepositoryProvider).markAsRead(id);
    } catch (_) {
      // Fallback on error
      ref.invalidateSelf();
    }
  }
}

final notificationsProvider = AsyncNotifierProvider<
    NotificationsNotifier, List<NotificationModel>>(
  NotificationsNotifier.new,
);
