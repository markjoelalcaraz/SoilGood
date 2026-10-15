/// Pure helpers for “which soil reading is live truth” on Home.
///
/// Extracted from Home so TC_HOME_001 / TC_HOME_002 can unit-test latest vs
/// stale vs empty without mounting widgets. Matches Realtime-vs-cache preference
/// and the 2h offline window used by notifications.
library;

import '../data/soil_reading.dart';

/// Same freshness window as [NotificationEvaluator.staleAfter].
const Duration kSoilReadingStaleAfter = Duration(hours: 2);

/// How Home should treat the current soil fetch result (no invented defaults).
enum LiveSoilTruthKind {
  /// No reading yet — show empty, not fake values.
  empty,

  /// Fetch failed — keep last-known only if caller still has it; else error.
  error,

  /// Have a row but it is older than [kSoilReadingStaleAfter].
  stale,

  /// Fresh enough to treat as current soil truth.
  live,
}

/// Newer of two candidates (Realtime stream vs pull cache). Null-safe.
SoilReading? preferLatest(SoilReading? a, SoilReading? b) {
  if (a == null) return b;
  if (b == null) return a;
  return a.recordedAt.isAfter(b.recordedAt) ? a : b;
}

/// Picks the newest `recorded_at` from a list. Null when empty.
SoilReading? pickLatestReading(Iterable<SoilReading> readings) {
  SoilReading? best;
  for (final r in readings) {
    best = preferLatest(best, r);
  }
  return best;
}

/// True when [reading] is at least [staleAfter] older than [now].
bool isSoilReadingStale(
  SoilReading reading,
  DateTime now, {
  Duration staleAfter = kSoilReadingStaleAfter,
}) {
  final recorded =
      reading.recordedAt.isUtc ? reading.recordedAt : reading.recordedAt.toUtc();
  return now.toUtc().difference(recorded) >= staleAfter;
}

/// Classifies empty / error / stale / live for farmer-facing Home truth.
///
/// Never invents moisture/pH. [fetchFailed] with a still-held [latest] stays
/// classified from that row (stale or live) so pull partial-failure can keep
/// dated last-known — callers show the error banner separately.
LiveSoilTruthKind classifyLiveSoilTruth({
  required bool fetchFailed,
  SoilReading? latest,
  required DateTime now,
  Duration staleAfter = kSoilReadingStaleAfter,
}) {
  if (latest == null) {
    return fetchFailed ? LiveSoilTruthKind.error : LiveSoilTruthKind.empty;
  }
  if (isSoilReadingStale(latest, now, staleAfter: staleAfter)) {
    return LiveSoilTruthKind.stale;
  }
  return LiveSoilTruthKind.live;
}
