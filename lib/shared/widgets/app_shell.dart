import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:expense_manager/app/theme/theme_provider.dart';
import 'package:go_router/go_router.dart';
import '../../features/notifications/data/notification_repository.dart';
import '../../features/profile/data/profile_repository.dart';

/// Main app shell with floating expandable bottom navigation and header.
class AppShell extends ConsumerWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  static const _tabs = [
    (
      icon: Icons.calendar_month_outlined,
      activeIcon: Icons.calendar_month,
      label: 'Calendar',
      path: '/calendar',
    ),
    (
      icon: Icons.account_balance_wallet_outlined,
      activeIcon: Icons.account_balance_wallet,
      label: 'Expenses',
      path: '/expenses',
    ),
    (
      icon: Icons.handshake_outlined,
      activeIcon: Icons.handshake,
      label: 'Settlement',
      path: '/settlement',
    ),
    (
      icon: Icons.group_outlined,
      activeIcon: Icons.group,
      label: 'Groups',
      path: '/groups',
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
    ref.watch(
      currentProfileProvider,
    ); // Force profile fetch/creation on startup
    final unreadCount =
        notificationsAsync.valueOrNull?.where((n) => !n.isRead).length ?? 0;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_balance_wallet, size: 22, color: AppColors.textPrimary),
            const SizedBox(width: 8),
            Text(
              'Expense Manager',
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
              child: Badge(
                isLabelVisible: unreadCount > 0,
                label: Text('$unreadCount'),
                backgroundColor: Colors.red,
                child: IconButton(
                  key: const Key('notifications_btn'),
                  icon: Icon(
                    Icons.notifications_outlined,
                    color: AppColors.textPrimary,
                  ),
                  onPressed: () => context.push('/notifications'),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () => context.push('/profile'),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.surface,
                  child: Icon(
                    Icons.person_outline,
                    size: 18,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          child,
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _ExpandableBottomNav(
              tabs: _tabs,
              currentIndex: currentIndex,
              onTap: (path) => context.go(path),
            ),
          ),
        ],
      ),
    );
  }
}

/// A premium floating expandable bottom navigation bar with spring animations.
class _ExpandableBottomNav extends StatefulWidget {
  final List<({IconData icon, IconData activeIcon, String label, String path})>
  tabs;
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
    
    // Total weight = (1 active tab * 1.8) + (3 inactive tabs * 1.0) = 4.8
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20.0, left: 16, right: 16),
            child: Container(
              height: 64, // Fixed height for the navigation bar
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: AppColors.borderLight, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.textPrimary.withValues(alpha: 0.08),
                    blurRadius: 24,
                    spreadRadius: 0,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final totalWidth = constraints.maxWidth;
                  final activeWidth = _getTabWidth(widget.currentIndex, totalWidth, widget.currentIndex);
                  final activeLeft = _getActiveLeft(totalWidth, widget.currentIndex);

                  return Stack(
                    children: [
                      // Sliding Background
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutBack,
                        left: activeLeft,
                        top: 0,
                        bottom: 0,
                        width: activeWidth,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: AppColors.textPrimary,
                            borderRadius: BorderRadius.circular(26),
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
                              onTap: () => widget.onTap(tab.path),
                              behavior: HitTestBehavior.opaque,
                              child: Center(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      AnimatedScale(
                                        scale: isActive ? 1.1 : 1.0,
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        curve: Curves.easeOutBack,
                                        child: Icon(
                                          isActive ? tab.activeIcon : tab.icon,
                                          color: isActive
                                              ? AppColors.surface
                                              : AppColors.textSecondary,
                                          size: 20,
                                        ),
                                      ),
                                      AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        curve: Curves.easeInOutCubic,
                                        width: isActive ? 64.0 : 0.0,
                                        child: ClipRect(
                                          child: isActive
                                              ? Padding(
                                                  padding: const EdgeInsets.only(
                                                    left: 6,
                                                  ),
                                                  child: Text(
                                                    tab.label,
                                                    style: TextStyle(
                                                      color: AppColors.surface,
                                                      fontWeight: FontWeight.w700,
                                                      fontSize: 11,
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
        ),
      ],
    );
  }
}
