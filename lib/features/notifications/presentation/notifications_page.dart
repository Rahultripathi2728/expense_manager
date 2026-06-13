import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:expense_manager/app/theme/theme_provider.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/utils/date_helpers.dart';
import '../../auth/data/auth_repository.dart';
import '../data/notification_repository.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(themeProvider);
    final notificationsAsync = ref.watch(notificationsProvider);
    final user = ref.watch(authStateProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (user != null) ...[
            TextButton(
              onPressed: () async {
                await ref
                    .read(notificationRepositoryProvider)
                    .markAllAsRead(user.id);
                ref.invalidate(notificationsProvider);
              },
              child: Text(
                'Read All',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                await ref
                    .read(notificationRepositoryProvider)
                    .clearAll(user.id);
                ref.invalidate(notificationsProvider);
              },
              child: Text(
                'Clear All',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'Error loading notifications',
            style: TextStyle(color: AppColors.error),
          ),
        ),
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'No notifications',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    "You're all caught up!",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notif = notifications[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: notif.isRead
                      ? AppColors.surfaceVariant
                      : AppColors.primary.withValues(alpha: 0.1),
                  child: Icon(
                    _iconForType(notif.type),
                    color: notif.isRead
                        ? AppColors.textTertiary
                        : AppColors.primary,
                  ),
                ),
                title: Text(
                  notif.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: notif.isRead
                        ? FontWeight.w400
                        : FontWeight.w600,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 2),
                    Text(
                      notif.body,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateHelpers.formatRelative(notif.createdAt),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
                onTap: () {
                  if (!notif.isRead) {
                    ref
                        .read(notificationRepositoryProvider)
                        .markAsRead(notif.id);
                    ref.invalidate(notificationsProvider);
                  }
                  // Handle payload navigation if needed
                },
              );
            },
          );
        },
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'expense_added':
        return Icons.receipt_long;
      case 'settled':
        return Icons.handshake;
      case 'joined_group':
        return Icons.group_add;
      case 'list_updated':
        return Icons.checklist;
      default:
        return Icons.notifications;
    }
  }
}
