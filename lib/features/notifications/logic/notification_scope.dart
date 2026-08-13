/// Inherited access to the shell's [NotificationController] for badges.
///
/// Wraps the app shell so the top-bar bell and any descendant can read unread
/// counts without prop-drilling. Not a farmer-facing page.
library;

import 'package:flutter/material.dart';

import 'notification_controller.dart';

/// Provides [NotificationController] below the signed-in shell.
class NotificationScope extends InheritedNotifier<NotificationController> {
  const NotificationScope({
    required NotificationController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  /// Null when the widget is not under the shell (login, onboarding).
  static NotificationController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<NotificationScope>()
        ?.notifier;
  }
}
