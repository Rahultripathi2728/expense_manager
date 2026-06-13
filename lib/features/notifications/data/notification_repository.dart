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
    for (final doc in res.rows) {
      await markAsRead(doc.$id);
    }
  }

  Future<void> clearAll(String userId) async {
    final res = await _tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.notificationsCollection,
      queries: [Query.equal('userId', userId)],
    );
    for (final doc in res.rows) {
      await _tablesDB.deleteRow(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.notificationsCollection,
        rowId: doc.$id,
      );
    }
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.watch(appwriteTablesDBProvider));
});

final notificationsProvider = FutureProvider<List<NotificationModel>>((
  ref,
) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return [];
  return ref.watch(notificationRepositoryProvider).getNotifications(user.id);
});
