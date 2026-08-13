/// Caps page content so large screens (Chrome, tablet) do not stretch cards
/// edge-to-edge.
///
/// App chrome stays full-bleed: [SoilGoodTopBar] and the shell bottom nav.
/// Wrap the **body** scroller only. Auth forms use [kAuthContentMaxWidth].
library;

import 'package:flutter/material.dart';

/// Dashboard / shell / onboarding body — phone-sized column on a wide screen.
const kAppContentMaxWidth = 600.0;

/// Login / signup card — tighter than dashboard cards.
const kAuthContentMaxWidth = 440.0;

/// Centers [child] and caps width. On a real phone this is a no-op.
class AppContentWidth extends StatelessWidget {
  const AppContentWidth({
    required this.child,
    this.maxWidth = kAppContentMaxWidth,
    super.key,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }
}
