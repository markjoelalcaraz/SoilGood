/// Main signed-in chrome of SoilGood: persistent bottom navigation + top bar helpers.
///
/// After auth and onboarding, the farmer lives here. Only the center content area
/// swaps between Home, Analytics, Crops, and Profile via IndexedStack — the nav
/// itself does not rebuild or slide away.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../analytics/presentation/analytics_page.dart';
import '../crops/presentation/crops_page.dart';
import '../home/presentation/home_page.dart';
import '../profile/presentation/profile_page.dart';

/// Persistent chrome: bottom nav stays; only the content area swaps.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _pages = [
    HomePage(),
    AnalyticsPage(),
    CropsPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primary,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home, color: Colors.white),
            label: 'Home',
          ),
          NavigationDestination(
            icon: const Icon(Icons.insights_outlined),
            selectedIcon: const Icon(Icons.insights, color: Colors.white),
            label: 'Analytics',
          ),
          NavigationDestination(
            icon: const Icon(Icons.eco_outlined),
            selectedIcon: const Icon(Icons.eco, color: Colors.white),
            label: 'Crops',
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person, color: Colors.white),
            label: 'Profile',
          ),
        ],
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
          Text(
            title,
            style: GoogleFonts.literata(
              fontWeight: FontWeight.w700,
              fontStyle: FontStyle.italic,
              color: AppColors.primary,
              fontSize: 22,
            ),
          ),
        ],
      ),
      actions: [
        if (showNotifications)
          IconButton(
            tooltip: 'Notifications (coming soon)',
            onPressed: () {},
            icon: const Icon(Icons.notifications_outlined),
          ),
      ],
    );
  }
}
