/// No-op auth-callback stash for phones. Web keeps the real address.
library;

/// The reset link address saved before Flutter starts. Always null here.
String? readStashedAuthCallback() => null;

/// Phones do not stash a browser address.
void clearStashedAuthCallback() {}
