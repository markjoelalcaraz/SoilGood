/// Main signed-in chrome of SoilGood: persistent bottom navigation + top bar helpers.
///
/// After auth and onboarding, the farmer lives here. Only the center content area
/// swaps between Home, Analytics, Crops, and Profile via IndexedStack — the nav
/// itself does not rebuild or slide away. Starts the farm-alert engine, shows
/// unread count on the bell, and red dots on tabs that have related alerts.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../shared/navigation/app_page_routes.dart';
import '../analytics/presentation/analytics_page.dart';
import '../crops/presentation/crops_page.dart';
import '../home/presentation/home_page.dart';
import '../notifications/logic/notification_controller.dart';
import '../notifications/logic/notification_scope.dart';
import '../notifications/presentation/notifications_page.dart';
import '../profile/presentation/profile_page.dart';

/// Lets feature pages jump to another shell tab (e.g. Home → Crops CTA).
class ShellScope extends InheritedWidget {
  const ShellScope({
    required this.selectTab,
    required super.child,
    super.key,
  });

  /// Bottom-nav indices: 0 Home, 1 Analytics, 2 Crops, 3 Profile.
  final void Function(int index) selectTab;

  /// Nearest shell scope, or null outside [AppShell].
  static ShellScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ShellScope>();
  }

  @override
  bool updateShouldNotify(ShellScope oldWidget) =>
      selectTab != oldWidget.selectTab;
}

/// Persistent chrome: bottom nav stays; only the content area swaps.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  final _notifications = NotificationController();

  static const _pages = [
    HomePage(),
    AnalyticsPage(),
    CropsPage(),
    ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    _notifications.start();
  }

  @override
  void dispose() {
    _notifications.dispose();
    super.dispose();
  }

  /// Swap the content tab and ack that tab's related alerts.
  void _onTabSelected(int value) {
    _notifications.markTabRead(value);
    setState(() => _index = value);
  }

  @override
  Widget build(BuildContext context) {
    return NotificationScope(
      controller: _notifications,
      child: ShellScope(
        selectTab: _onTabSelected,
        child: ListenableBuilder(
          listenable: _notifications,
          builder: (context, _) {
            return Scaffold(
              body: IndexedStack(index: _index, children: _pages),
              bottomNavigationBar: NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: _onTabSelected,
                backgroundColor: AppColors.surface,
                indicatorColor: AppColors.primary,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                destinations: [
                  NavigationDestination(
                    icon: _tabIcon(
                      Icons.home_outlined,
                      unread: _notifications.tabHasUnread(0),
                    ),
                    selectedIcon: const Icon(Icons.home, color: Colors.white),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: _tabIcon(
                      Icons.insights_outlined,
                      unread: _notifications.tabHasUnread(1),
                    ),
                    selectedIcon:
                        const Icon(Icons.insights, color: Colors.white),
                    label: 'Analytics',
                  ),
                  NavigationDestination(
                    icon: _tabIcon(
                      Icons.eco_outlined,
                      unread: _notifications.tabHasUnread(2),
                    ),
                    selectedIcon: const Icon(Icons.eco, color: Colors.white),
                    label: 'Crops',
                  ),
                  NavigationDestination(
                    icon: _tabIcon(
                      Icons.person_outline,
                      unread: _notifications.tabHasUnread(3),
                    ),
                    selectedIcon: const Icon(Icons.person, color: Colors.white),
                    label: 'Profile',
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Red dot on unselected tabs that have related unread alerts.
  Widget _tabIcon(IconData icon, {required bool unread}) {
    if (!unread) return Icon(icon);
    return Badge(
      smallSize: 8,
      backgroundColor: AppColors.error,
      child: Icon(icon),
    );
  }
}

/// Shared top bar used by feature pages (content area only under the shell).
class SoilGoodTopBar extends StatelessWidget implements PreferredSizeWidget {
  const SoilGoodTopBar({
    required this.title,
    this.showNotifications = true,
    this.leadingIcon = Icons.eco,
    super.key,
  });

  final String title;
  final bool showNotifications;
  final IconData leadingIcon;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final unread = NotificationScope.maybeOf(context)?.unreadCount ?? 0;

    return AppBar(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.primary,
      elevation: 0,
      scrolledUnderElevation: 1,
      titleSpacing: 16,
      title: Row(
        children: [
          Icon(leadingIcon, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.literata(
                fontWeight: FontWeight.w700,
                fontStyle: FontStyle.italic,
                color: AppColors.primary,
                fontSize: 22,
              ),
            ),
          ),
        ],
      ),
      actions: [
        if (showNotifications)
          IconButton(
            tooltip: unread == 0
                ? 'Notifications'
                : 'Notifications ($unread unread)',
            onPressed: () {
              Navigator.of(context).push(
                AppPageRoutes.slideFromRight(const NotificationsPage()),
              );
            },
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text(unread > 9 ? '9+' : '$unread'),
              backgroundColor: AppColors.error,
              textColor: Colors.white,
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
      ],
    );
  }
}
