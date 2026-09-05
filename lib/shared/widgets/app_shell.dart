import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/utils/haptic_helper.dart';
import '../../app/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:expense_manager/app/theme/theme_provider.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/notifications/data/notification_repository.dart';
import '../../features/profile/data/profile_repository.dart';
import 'split_pro_logo.dart';

/// Main app shell with fixed bottom navigation bar and header.
class AppShell extends ConsumerWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  static const _tabs = [
    (
      icon: Icons.calendar_today_rounded,
      activeIcon: Icons.calendar_month_rounded,
      label: 'Calendar',
      path: '/calendar',
    ),
    (
      icon: Icons.receipt_long_rounded,
      activeIcon: Icons.receipt_rounded,
      label: 'Expenses',
      path: '/expenses',
    ),
    (
      icon: Icons.people_outline_rounded,
      activeIcon: Icons.people_rounded,
      label: 'Groups',
      path: '/groups',
    ),
    (
      icon: Icons.shopping_cart_outlined,
      activeIcon: Icons.shopping_cart_rounded,
      label: 'Items',
      path: '/items',
    ),
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final idx = _tabs.indexWhere((t) => location.startsWith(t.path));
    return idx >= 0 ? idx : 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(themeProvider);
    final currentIndex = _currentIndex(context);
    final notificationsAsync = ref.watch(notificationsProvider);
    final authUser = ref.watch(authStateProvider).valueOrNull;
    ref.watch(currentProfileProvider); // Force profile fetch/creation on startup
    final unreadCount =
        notificationsAsync.valueOrNull?.where((n) => !n.isRead).length ?? 0;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SplitProLogo(size: 26),
            const SizedBox(width: 8),
            Text(
              'Split Pro',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Builder(
                builder: (context) {
                  Widget bellIcon = Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      key: const Key('notifications_btn'),
                      icon: Icon(
                        Icons.notifications_rounded,
                        size: 20,
                        color: unreadCount > 0 ? AppColors.primary : AppColors.textSecondary,
                      ),
                      onPressed: () => context.push('/notifications'),
                    ),
                  );

                  if (unreadCount > 0) {
                    bellIcon = bellIcon.animate(
                      onPlay: (controller) => controller.repeat(),
                    ).shake(
                      hz: 3,
                      curve: Curves.easeInOutCubic,
                      duration: 450.ms,
                    ).scale(
                      begin: const Offset(1, 1),
                      end: const Offset(1.08, 1.08),
                      duration: 200.ms,
                      curve: Curves.easeOut,
                    ).then().scale(
                      begin: const Offset(1.08, 1.08),
                      end: const Offset(1, 1),
                      duration: 200.ms,
                      curve: Curves.easeIn,
                    ).then(delay: 2500.ms);
                  }

                  return Badge(
                    isLabelVisible: unreadCount > 0,
                    label: Text(
                      '$unreadCount',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                    ),
                    backgroundColor: AppColors.error,
                    offset: const Offset(-2, 2),
                    child: bellIcon,
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () => context.push('/profile'),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary,
                      const Color(0xFF41A5FF),
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    authUser?.name.isNotEmpty == true
                        ? authUser!.name[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: child,
      bottomNavigationBar: _ExpandableBottomNav(
        tabs: _tabs,
        currentIndex: currentIndex,
        onTap: (path) => context.go(path),
      ),
    );
  }
}

/// A fixed persistent bottom navigation bar with full spring animations and sliding active tab pill.
class _ExpandableBottomNav extends StatefulWidget {
  final List<({IconData icon, IconData activeIcon, String label, String path})> tabs;
  final int currentIndex;
  final ValueChanged<String> onTap;

  const _ExpandableBottomNav({
    required this.tabs,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<_ExpandableBottomNav> createState() => _ExpandableBottomNavState();
}

class _ExpandableBottomNavState extends State<_ExpandableBottomNav> {
  double _getTabWidth(int index, double totalWidth, int currentIndex) {
    const double activeWeight = 1.8;
    const double inactiveWeight = 1.0;
    final double totalWeight = activeWeight + (widget.tabs.length - 1) * inactiveWeight;
    final bool isActive = index == currentIndex;
    final double weight = isActive ? activeWeight : inactiveWeight;
    return totalWidth * (weight / totalWeight);
  }

  double _getActiveLeft(double totalWidth, int currentIndex) {
    double left = 0.0;
    for (int i = 0; i < currentIndex; i++) {
      left += _getTabWidth(i, totalWidth, currentIndex);
    }
    return left;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.borderLight, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final totalWidth = constraints.maxWidth;
              final activeWidth = _getTabWidth(widget.currentIndex, totalWidth, widget.currentIndex);
              final activeLeft = _getActiveLeft(totalWidth, widget.currentIndex);

              return Stack(
                children: [
                  // Sliding Background Pill with spring curve
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutBack,
                    left: activeLeft,
                    top: 2,
                    bottom: 2,
                    width: activeWidth,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  // Tab Buttons
                  Row(
                    children: List.generate(widget.tabs.length, (index) {
                      final tab = widget.tabs[index];
                      final isActive = index == widget.currentIndex;
                      final currentTabWidth = _getTabWidth(index, totalWidth, widget.currentIndex);

                      return SizedBox(
                        width: currentTabWidth,
                        child: GestureDetector(
                          onTap: () {
                            HapticHelper.selectionClick();
                            widget.onTap(tab.path);
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 6,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    AnimatedScale(
                                      scale: isActive ? 1.12 : 1.0,
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeOutBack,
                                      child: Icon(
                                        isActive ? tab.activeIcon : tab.icon,
                                        color: isActive
                                            ? AppColors.primary
                                            : AppColors.textSecondary,
                                        size: 21,
                                      ),
                                    ),
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeInOutCubic,
                                      width: isActive ? 68.0 : 0.0,
                                      child: ClipRect(
                                        child: isActive
                                            ? Padding(
                                                padding: const EdgeInsets.only(left: 6),
                                                child: Text(
                                                  tab.label,
                                                  style: TextStyle(
                                                    color: AppColors.primary,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 12,
                                                    letterSpacing: -0.2,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.fade,
                                                  softWrap: false,
                                                ),
                                              )
                                            : const SizedBox.shrink(),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
