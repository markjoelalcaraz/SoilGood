/// Reads the reset-link address saved by web/index.html before Flutter boots.
///
/// Web only. The stub is used on phones. Not a widget.
library;

import 'package:web/web.dart';

const _stashKey = 'soilgood.authCallback';

/// Full browser address captured while the recovery token was still present.
String? readStashedAuthCallback() => window.sessionStorage.getItem(_stashKey);

/// Drops the stashed address after it has been exchanged for a session.
void clearStashedAuthCallback() {
  window.sessionStorage.removeItem(_stashKey);
}
