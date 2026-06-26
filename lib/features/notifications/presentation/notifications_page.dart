import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:expense_manager/app/theme/theme_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/utils/date_helpers.dart';
import '../../auth/data/auth_repository.dart';
import '../data/notification_repository.dart';
import '../../../shared/widgets/skeleton_loading_card.dart';
import '../../../core/utils/haptic_helper.dart';

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
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(
          'Notifications',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (user != null) ...[
            TextButton(
              onPressed: () {
                HapticHelper.mediumTap();
                ref.read(notificationsProvider.notifier).markAllNotificationsAsRead();
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
              onPressed: () {
                HapticHelper.mediumTap();
                ref.read(notificationsProvider.notifier).clearAllNotifications();
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
            const SizedBox(width: 8),
          ],
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: SkeletonList(itemCount: 5),
        ),
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
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.notifications_off_outlined,
                      size: 48,
                      color: AppColors.textTertiary,
                    ),
                  )
                      .animate(onPlay: (controller) => controller.repeat(reverse: true))
                      .scale(
                        begin: const Offset(0.95, 0.95),
                        end: const Offset(1.05, 1.05),
                        duration: 2000.ms,
                        curve: Curves.easeInOut,
                      ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'No notifications',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    "You're all caught up!",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ).animate().fade(duration: 400.ms);
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notif = notifications[index];
              return Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: notif.isRead
                      ? AppColors.surface
                      : AppColors.surfaceVariant.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: notif.isRead
                        ? AppColors.borderLight
                        : AppColors.textPrimary.withValues(alpha: 0.1),
                    width: notif.isRead ? 1.0 : 1.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: notif.isRead
                            ? AppColors.surfaceVariant
                            : AppColors.textPrimary.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _iconForType(notif.type),
                        color: notif.isRead
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      notif.title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight:
                                notif.isRead ? FontWeight.w500 : FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          notif.body,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.3,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          DateHelpers.formatRelative(notif.createdAt),
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AppColors.textTertiary,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ],
                    ),
                    onTap: () {
                      if (!notif.isRead) {
                        HapticHelper.lightTap();
                        ref
                            .read(notificationsProvider.notifier)
                            .markNotificationAsRead(notif.id);
                      }
                    },
                  ),
                ),
              )
                  .animate()
                  .fade(duration: 400.ms, delay: (index * 60).ms)
                  .slideY(
                    begin: 0.2,
                    end: 0,
                    curve: Curves.easeOutCirc,
                    duration: 500.ms,
                  )
                  .scale(
                    begin: const Offset(0.95, 0.95),
                    end: const Offset(1, 1),
                    curve: Curves.easeOutCirc,
                    duration: 500.ms,
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
        return Icons.receipt_long_outlined;
      case 'settled':
        return Icons.handshake_outlined;
      case 'joined_group':
        return Icons.group_add_outlined;
      case 'list_updated':
        return Icons.checklist_outlined;
      default:
        return Icons.notifications_none_outlined;
    }
  }
}
