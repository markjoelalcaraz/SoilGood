/// Caps pull-to-refresh / first-load network work so a weak field signal
/// cannot spin the UI forever.
///
/// Used by data screens (Home, Analytics, Crops, Profile, Notifications). Not a
/// widget — call [withRefreshTimeout] around repository/API futures.
library;

/// Farmer-visible timeout for one refresh source (soil, weather, …).
const kRefreshTimeout = Duration(seconds: 15);

/// Fails [future] with a short message if it exceeds [kRefreshTimeout].
Future<T> withRefreshTimeout<T>(Future<T> future) {
  return future.timeout(
    kRefreshTimeout,
    onTimeout: () => throw const RefreshTimeoutException(),
  );
}

/// Thrown when a refresh source does not finish in time.
class RefreshTimeoutException implements Exception {
  const RefreshTimeoutException();

  @override
  String toString() => 'Refresh timed out. Check your connection.';
}
