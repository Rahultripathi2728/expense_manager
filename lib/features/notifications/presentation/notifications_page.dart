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
import '../domain/notification_model.dart';
import '../../../shared/widgets/skeleton_loading_card.dart';
import '../../../core/utils/haptic_helper.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  String _selectedFilter = 'all'; // 'all', 'unread', 'payments', 'expenses', 'groups'

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    final notificationsAsync = ref.watch(notificationsProvider);
    final user = ref.watch(authStateProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: false,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: InkWell(
            onTap: () {
              HapticHelper.lightTap();
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/calendar');
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary, size: 20),
            ),
          ),
        ),
        title: Row(
          children: [
            Text(
              'Notifications',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            notificationsAsync.when(
              data: (notifs) {
                final unreadCount = notifs.where((n) => !n.isRead).length;
                if (unreadCount == 0) return const SizedBox.shrink();
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    '$unreadCount New',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
        actions: [
          if (user != null) ...[
            // Mark all read button
            IconButton(
              icon: Icon(Icons.done_all_rounded, color: AppColors.primary, size: 22),
              tooltip: 'Mark All Read',
              onPressed: () {
                HapticHelper.mediumTap();
                ref.read(notificationsProvider.notifier).markAllNotificationsAsRead();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All notifications marked as read'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),

            // Clear all button
            IconButton(
              icon: Icon(Icons.delete_sweep_outlined, color: AppColors.textSecondary, size: 22),
              tooltip: 'Clear All',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Clear all notifications?'),
                    content: const Text('This will remove all notification records from your history.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text('Cancel', style: TextStyle(color: AppColors.textPrimary)),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Clear All', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  HapticHelper.mediumTap();
                  ref.read(notificationsProvider.notifier).clearAllNotifications();
                }
              },
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: SkeletonList(itemCount: 6),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text(
                'Error loading notifications',
                style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        data: (allNotifications) {
          if (allNotifications.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primary.withValues(alpha: 0.12),
                            AppColors.surfaceVariant,
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.notifications_none_rounded,
                        size: 52,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'No Notifications Yet',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You are all caught up! When group members add expenses, settle up, or update lists, updates will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ).animate().fade(duration: 400.ms);
          }

          // Filter by selected tab
          final filtered = allNotifications.where((n) {
            if (_selectedFilter == 'unread') return !n.isRead;
            if (_selectedFilter == 'payments') return n.type == 'settled' || n.type == 'payment';
            if (_selectedFilter == 'expenses') return n.type == 'expense_added' || n.type == 'expense' || n.type == 'expense_deleted';
            if (_selectedFilter == 'groups') return n.type == 'joined_group' || n.type == 'group';
            return true;
          }).toList();

          final countUnread = allNotifications.where((n) => !n.isRead).length;
          final countPayments = allNotifications.where((n) => n.type == 'settled' || n.type == 'payment').length;
          final countExpenses = allNotifications.where((n) => n.type == 'expense_added' || n.type == 'expense' || n.type == 'expense_deleted').length;
          final countGroups = allNotifications.where((n) => n.type == 'joined_group' || n.type == 'group').length;

          return Column(
            children: [
              // Filter Chips Row
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _buildFilterChip('all', 'All (${allNotifications.length})'),
                      const SizedBox(width: 8),
                      _buildFilterChip('unread', '🔴 Unread ($countUnread)'),
                      const SizedBox(width: 8),
                      _buildFilterChip('payments', '💰 Payments ($countPayments)'),
                      const SizedBox(width: 8),
                      _buildFilterChip('expenses', '🧾 Expenses ($countExpenses)'),
                      const SizedBox(width: 8),
                      _buildFilterChip('groups', '👥 Groups ($countGroups)'),
                    ],
                  ),
                ),
              ),

              // Notification List
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No notifications in this filter.',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                      )
                    : Builder(
                        builder: (context) {
                          // Group notifications by date
                          final Map<String, List<NotificationModel>> grouped = {};
                          final now = DateTime.now();
                          final yesterday = now.subtract(const Duration(days: 1));

                          for (final notif in filtered) {
                            String header;
                            if (DateHelpers.isSameDay(notif.createdAt, now)) {
                              header = 'Recent';
                            } else if (DateHelpers.isSameDay(notif.createdAt, yesterday)) {
                              header = 'Yesterday';
                            } else {
                              header = DateHelpers.formatFullDate(notif.createdAt);
                            }
                            grouped.putIfAbsent(header, () => []).add(notif);
                          }

                          final groupEntries = grouped.entries.toList();

                          return ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                            physics: const BouncingScrollPhysics(),
                            itemCount: groupEntries.length,
                            itemBuilder: (context, groupIndex) {
                              final entry = groupEntries[groupIndex];
                              final header = entry.key;
                              final items = entry.value;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 14, bottom: 8, left: 4, right: 4),
                                    child: Row(
                                      children: [
                                        Text(
                                          header,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textSecondary,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Container(
                                            height: 1,
                                            color: AppColors.borderLight,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ...items.asMap().entries.map((itemEntry) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: _buildNotificationItem(context, itemEntry.value, itemEntry.key),
                                    );
                                  }),
                                ],
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedFilter == key;

    return GestureDetector(
      onTap: () {
        HapticHelper.selectionClick();
        setState(() => _selectedFilter = key);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.borderLight,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationItem(BuildContext context, NotificationModel notif, int index) {
    final meta = _getNotificationMeta(notif.type);

    return Dismissible(
      key: Key(notif.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
      ),
      onDismissed: (_) {
        HapticHelper.lightTap();
        ref.read(notificationsProvider.notifier).deleteNotification(notif.id);
      },
      child: InkWell(
        onTap: () {
          if (!notif.isRead) {
            HapticHelper.lightTap();
            ref.read(notificationsProvider.notifier).markNotificationAsRead(notif.id);
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: notif.isRead ? AppColors.surface : AppColors.surfaceVariant.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: notif.isRead
                  ? AppColors.borderLight
                  : meta.color.withValues(alpha: 0.35),
              width: notif.isRead ? 1.0 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Vibrant Category Icon Badge
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: meta.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: meta.color.withValues(alpha: 0.25), width: 1.2),
                ),
                child: Center(
                  child: Icon(
                    meta.icon,
                    color: meta.color,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Title & Body
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notif.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (!notif.isRead) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: meta.color,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: meta.color.withValues(alpha: 0.5),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notif.body,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 12, color: AppColors.textTertiary),
                        const SizedBox(width: 4),
                        Text(
                          DateHelpers.formatTime(notif.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fade(duration: 350.ms, delay: (index * 40).ms)
        .slideY(
          begin: 0.1,
          end: 0,
          curve: Curves.easeOutCirc,
          duration: 400.ms,
        );
  }

  _NotificationTypeMeta _getNotificationMeta(String type) {
    switch (type.toLowerCase().trim()) {
      case 'settled':
      case 'payment':
        return _NotificationTypeMeta(
          icon: Icons.payments_rounded,
          color: const Color(0xFF10B981),
        );
      case 'expense_added':
      case 'expense':
        return _NotificationTypeMeta(
          icon: Icons.receipt_long_rounded,
          color: AppColors.primary,
        );
      case 'expense_deleted':
        return _NotificationTypeMeta(
          icon: Icons.delete_outline_rounded,
          color: const Color(0xFFEF4444),
        );
      case 'joined_group':
      case 'group':
        return _NotificationTypeMeta(
          icon: Icons.group_add_rounded,
          color: const Color(0xFF8B5CF6),
        );
      case 'list_updated':
      case 'item':
        return _NotificationTypeMeta(
          icon: Icons.checklist_rounded,
          color: const Color(0xFFF59E0B),
        );
      default:
        return _NotificationTypeMeta(
          icon: Icons.notifications_rounded,
          color: AppColors.primary,
        );
    }
  }
}

class _NotificationTypeMeta {
  final IconData icon;
  final Color color;

  _NotificationTypeMeta({required this.icon, required this.color});
}
