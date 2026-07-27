/// Shared navigation helper for pages pushed outside the shell content area.
///
/// Shell tab switches stay instant (IndexedStack). Signup, Crop Plan, onboarding
/// advances, and similar full-screen pushes should use slideFromRight here.
library;

import 'package:flutter/material.dart';

/// Shared page transitions for SoilGood navigation.
///
/// - **Shell tabs** (Home / Analytics / Crops / Profile): no slide — IndexedStack swap.
/// - **Pushed screens** (outside shell chrome): slide in **from the right**.
class AppPageRoutes {
  AppPageRoutes._();

  /// Push a full-screen page that is not a shell tab.
  static Route<T> slideFromRight<T extends Object?>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1, 0);
        const end = Offset.zero;
        final tween = Tween(
          begin: begin,
          end: end,
        ).chain(CurveTween(curve: Curves.easeOutCubic));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 240),
    );
  }
}
