/// Main signed-in chrome of SoilGood: persistent bottom navigation + top bar helpers.
///
/// After auth and onboarding, the farmer lives here. Only the center content area
/// swaps between Home, Farm, Analytics, and Profile via IndexedStack — the nav
/// itself does not rebuild or slide away. Starts the farm-alert engine and the
/// Realtime hub (soil, plantings, sensors, AI, irrigation), shows unread count
/// on the bell, and red dots on tabs that have related alerts.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/live/farm_live_hub.dart';
import '../../core/live/farm_live_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/navigation/app_page_routes.dart';
import '../analytics/presentation/analytics_page.dart';
import '../farm/presentation/farm_map_page.dart';
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

  /// Bottom-nav indices: 0 Home, 1 Farm, 2 Analytics, 3 Profile.
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
  final _live = FarmLiveHub();

  static const _pages = [
    HomePage(),
    FarmMapPage(),
    AnalyticsPage(),
    ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    _notifications.start();
    _live.start();
  }

  @override
  void dispose() {
    _live.dispose();
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
    return FarmLiveScope(
      hub: _live,
      child: NotificationScope(
      controller: _notifications,
      child: ShellScope(
        selectTab: _onTabSelected,
        child: ListenableBuilder(
          listenable: _notifications,
          builder: (context, _) {
            return Scaffold(
              backgroundColor: AppColors.background,
              body: IndexedStack(index: _index, children: _pages),
              bottomNavigationBar: _FamilyNavBar(
                index: _index,
                onSelected: _onTabSelected,
                unread: _notifications.tabHasUnread,
              ),
            );
          },
        ),
      ),
    ),
    );
  }
}

/// Mock nav: white sheet, and the selected tab is one light-green pill.
class _FamilyNavBar extends StatelessWidget {
  const _FamilyNavBar({
    required this.index,
    required this.onSelected,
    required this.unread,
  });

  final int index;
  final ValueChanged<int> onSelected;
  final bool Function(int tab) unread;

  static const _tabs = [
    (Icons.home_outlined, Icons.home, 'Home'),
    (Icons.spa_outlined, Icons.spa, 'Farm'),
    (Icons.show_chart, Icons.show_chart, 'Analytics'),
    (Icons.person_outline, Icons.person, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x142E3230),
            blurRadius: 18,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 74,
          child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
          child: Row(
            children: [
              for (var i = 0; i < _tabs.length; i++)
                Expanded(
                  child: _NavSlot(
                    icon: _tabs[i].$1,
                    selectedIcon: _tabs[i].$2,
                    label: _tabs[i].$3,
                    selected: index == i,
                    showDot: unread(i) && index != i,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
        ),
      ),
    ),
    );
  }
}

class _NavSlot extends StatelessWidget {
  const _NavSlot({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.showDot,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final bool showDot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.navIcon : AppColors.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: selected ? AppColors.primarySoft : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Badge(
                isLabelVisible: showDot,
                smallSize: 7,
                backgroundColor: AppColors.error,
                child: Icon(
                  selected ? selectedIcon : icon,
                  size: 22,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.nunitoSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
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
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 16,
      title: Row(
        children: [
          Icon(leadingIcon, color: AppColors.navIcon),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.literata(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                fontSize: 22,
              ),
            ),
          ),
        ],
      ),
      actions: [
        if (showNotifications)
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 2,
              shadowColor: const Color(0x332E3230),
              child: IconButton(
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
                  child: const Icon(
                    Icons.notifications_outlined,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
