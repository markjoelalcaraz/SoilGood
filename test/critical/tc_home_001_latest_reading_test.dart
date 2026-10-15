/// TC_HOME_001 / TC_HOME_002 — live soil truth selection (unit).
///
/// Related: TS-03 Live Home soil truth. Docs: docs/testing/CRITICAL_TEST_CASES.md
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:soil_sense/features/home/data/soil_reading.dart';
import 'package:soil_sense/features/home/logic/live_soil_truth.dart';

void main() {
  final now = DateTime.utc(2026, 9, 17, 12, 0, 0);

  SoilReading reading({
    required String id,
    required DateTime recordedAt,
    double? moisture,
    double? ph,
  }) {
    return SoilReading(
      id: id,
      recordedAt: recordedAt,
      moisturePercent: moisture,
      ph: ph,
    );
  }

  group('TC_HOME_001 latest reading wins', () {
    test('pickLatestReading chooses newest recorded_at', () {
      final older = reading(
        id: 'a',
        recordedAt: now.subtract(const Duration(hours: 3)),
        moisture: 20,
      );
      final newer = reading(
        id: 'b',
        recordedAt: now.subtract(const Duration(minutes: 5)),
        moisture: 42,
        ph: 6.4,
      );

      final latest = pickLatestReading([older, newer]);
      expect(latest?.id, 'b');
      expect(latest?.moisturePercent, 42);
      expect(latest?.ph, 6.4);
    });

    test('preferLatest keeps pull cache when it is newer than stream', () {
      final stream = reading(
        id: 'stream',
        recordedAt: now.subtract(const Duration(minutes: 30)),
        moisture: 30,
      );
      final cached = reading(
        id: 'cache',
        recordedAt: now.subtract(const Duration(minutes: 5)),
        moisture: 42,
      );
      expect(preferLatest(stream, cached)?.id, 'cache');
    });
  });

  group('TC_HOME_002 empty / error / stale never look fresh-ok', () {
    test('empty list → empty kind (no invented values)', () {
      expect(pickLatestReading(const []), isNull);
      expect(
        classifyLiveSoilTruth(fetchFailed: false, latest: null, now: now),
        LiveSoilTruthKind.empty,
      );
    });

    test('fetch failed with no reading → error kind', () {
      expect(
        classifyLiveSoilTruth(fetchFailed: true, latest: null, now: now),
        LiveSoilTruthKind.error,
      );
    });

    test('reading older than 2h → stale, not live', () {
      final old = reading(
        id: 'old',
        recordedAt: now.subtract(const Duration(hours: 5)),
        moisture: 40,
      );
      expect(isSoilReadingStale(old, now), isTrue);
      expect(
        classifyLiveSoilTruth(fetchFailed: false, latest: old, now: now),
        LiveSoilTruthKind.stale,
      );
    });

    test('fresh reading → live', () {
      final fresh = reading(
        id: 'fresh',
        recordedAt: now.subtract(const Duration(minutes: 10)),
        moisture: 42,
      );
      expect(
        classifyLiveSoilTruth(fetchFailed: false, latest: fresh, now: now),
        LiveSoilTruthKind.live,
      );
    });
  });
}
