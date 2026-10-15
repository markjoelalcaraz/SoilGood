/// Shell access to [FarmLiveHub] for every data page under the signed-in app.
///
/// Same idea as the notification scope: the hub is started once, and pages
/// listen without opening their own Realtime channels. Not a farmer page.
library;

import 'package:flutter/material.dart';

import 'farm_live_hub.dart';

/// Provides the shell's live hub to descendant pages.
class FarmLiveScope extends InheritedNotifier<FarmLiveHub> {
  const FarmLiveScope({
    required FarmLiveHub hub,
    required super.child,
    super.key,
  }) : super(notifier: hub);

  /// Null outside the signed-in shell (login, onboarding).
  static FarmLiveHub? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<FarmLiveScope>()?.notifier;
  }
}
