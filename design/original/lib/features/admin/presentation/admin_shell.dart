/// Admin website chrome — collapsible sidebar, Analytics + Devices + Profile.
///
/// Shown when profiles.role = admin. Not the farmer bottom-nav shell. Wide:
/// sidebar icons+labels (toggle collapse to icons-only). Narrow: hamburger drawer.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/supabase/supabase_bootstrap.dart';
import '../../../core/theme/app_colors.dart';
import 'admin_analytics_page.dart';
import 'admin_devices_page.dart';
import 'admin_profile_page.dart';

/// Top-level admin host after AuthGate detects an admin session.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;
  /// When true on wide layouts: show icon + label. When false: icons only.
  bool _navExpanded = true;

  static const _titles = ['Analytics', 'Devices', 'Profile'];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final useDrawer = width < 900;

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: useDrawer
          ? Drawer(
              backgroundColor: AppColors.surface,
              child: SafeArea(
                child: _AdminNavBody(
                  index: _index,
                  expanded: true,
                  showCollapseToggle: false,
                  onSelect: (i) {
                    setState(() => _index = i);
                    Navigator.of(context).pop();
                  },
                  onToggleExpand: null,
                ),
              ),
            )
          : null,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!useDrawer)
            _AdminSideRail(
              index: _index,
              expanded: _navExpanded,
              onSelect: (i) => setState(() => _index = i),
              onToggleExpand: () =>
                  setState(() => _navExpanded = !_navExpanded),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AdminTopBar(
                  title: _titles[_index],
                  showMenu: useDrawer,
                ),
                Expanded(
                  child: IndexedStack(
                    index: _index,
                    children: const [
                      AdminAnalyticsPage(),
                      AdminDevicesPage(),
                      AdminProfilePage(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Top bar with optional hamburger (narrow) and sign-out.
class _AdminTopBar extends StatelessWidget {
  const _AdminTopBar({
    required this.title,
    required this.showMenu,
  });

  final String title;
  final bool showMenu;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: AppColors.outline.withValues(alpha: 0.35),
              ),
            ),
          ),
          child: Row(
            children: [
              if (showMenu)
                IconButton(
                  tooltip: 'Menu',
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  icon: const Icon(Icons.menu, color: AppColors.primary),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.literata(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => supabase.auth.signOut(),
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fixed left rail — expands (icons+labels) or collapses (icons only).
class _AdminSideRail extends StatelessWidget {
  const _AdminSideRail({
    required this.index,
    required this.expanded,
    required this.onSelect,
    required this.onToggleExpand,
  });

  final int index;
  final bool expanded;
  final ValueChanged<int> onSelect;
  final VoidCallback onToggleExpand;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: expanded ? 240 : 72,
      child: Material(
        color: AppColors.surface,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(
                color: AppColors.outline.withValues(alpha: 0.35),
              ),
            ),
          ),
          child: SafeArea(
            child: _AdminNavBody(
              index: index,
              expanded: expanded,
              showCollapseToggle: true,
              onSelect: onSelect,
              onToggleExpand: onToggleExpand,
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared nav list for sidebar and drawer.
class _AdminNavBody extends StatelessWidget {
  const _AdminNavBody({
    required this.index,
    required this.expanded,
    required this.showCollapseToggle,
    required this.onSelect,
    required this.onToggleExpand,
  });

  final int index;
  final bool expanded;
  final bool showCollapseToggle;
  final ValueChanged<int> onSelect;
  final VoidCallback? onToggleExpand;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(expanded ? 20 : 12, 20, 12, 8),
          child: expanded
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SoilGood',
                      style: GoogleFonts.literata(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Admin console',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                )
              : Tooltip(
                  message: 'SoilGood Admin',
                  child: Icon(
                    Icons.eco,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
        ),
        if (showCollapseToggle)
          Align(
            alignment: expanded ? Alignment.centerRight : Alignment.center,
            child: IconButton(
              tooltip: expanded ? 'Collapse menu' : 'Expand menu',
              onPressed: onToggleExpand,
              icon: Icon(
                expanded ? Icons.chevron_left : Icons.chevron_right,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        const SizedBox(height: 8),
        _NavItem(
          expanded: expanded,
          selected: index == 0,
          icon: Icons.insights_outlined,
          selectedIcon: Icons.insights,
          label: 'Analytics',
          onTap: () => onSelect(0),
        ),
        _NavItem(
          expanded: expanded,
          selected: index == 1,
          icon: Icons.memory_outlined,
          selectedIcon: Icons.memory,
          label: 'Devices',
          onTap: () => onSelect(1),
        ),
        _NavItem(
          expanded: expanded,
          selected: index == 2,
          icon: Icons.person_outline,
          selectedIcon: Icons.person,
          label: 'Profile',
          onTap: () => onSelect(2),
        ),
        const Spacer(),
        _NavItem(
          expanded: expanded,
          selected: false,
          icon: Icons.logout,
          selectedIcon: Icons.logout,
          label: 'Sign out',
          onTap: () => supabase.auth.signOut(),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.expanded,
    required this.selected,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.onTap,
  });

  final bool expanded;
  final bool selected;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;
    final bg = selected
        ? AppColors.primarySoft.withValues(alpha: 0.55)
        : Colors.transparent;

    final child = Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: expanded ? 14 : 0,
            vertical: 12,
          ),
          child: expanded
              ? Row(
                  children: [
                    Icon(
                      selected ? selectedIcon : icon,
                      color: color,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: color,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                )
              : Center(
                  child: Icon(
                    selected ? selectedIcon : icon,
                    color: color,
                    size: 22,
                  ),
                ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: expanded
          ? child
          : Tooltip(message: label, child: child),
    );
  }
}
