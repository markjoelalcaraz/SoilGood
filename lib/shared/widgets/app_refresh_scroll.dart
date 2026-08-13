/// Page-level pull-to-refresh scroller for SoilGood data screens.
///
/// Wraps the **vertical** page ListView only (capped by [AppContentWidth]).
/// Nested horizontal lists (forecast, chips, phases) stay inside [children]
/// and must not get their own [RefreshIndicator]. Shell content area only.
library;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'app_content_width.dart';

/// Vertical ListView with [RefreshIndicator] and overscroll so pull works
/// even when content is shorter than the screen.
class AppRefreshScroll extends StatelessWidget {
  const AppRefreshScroll({
    required this.onRefresh,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 24),
    super.key,
  });

  final Future<void> Function() onRefresh;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return AppContentWidth(
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: padding,
          children: children,
        ),
      ),
    );
  }
}
