/// TC_ALERT_001 / TC_ALERT_002 — device_offline + sensor_error evaluator (unit).
///
/// Related: TS-05 Critical alerts. Docs: docs/testing/CRITICAL_TEST_CASES.md
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:soil_sense/features/home/data/soil_reading.dart';
import 'package:soil_sense/features/notifications/data/farm_notification.dart';
import 'package:soil_sense/features/notifications/logic/notification_evaluator.dart';

void main() {
  const evaluator = NotificationEvaluator();
  const farmId = 'farm-critical-001';
  final now = DateTime.utc(2026, 9, 17, 12, 0, 0);

  /// Neutral facts so irrigation/nutrient/soil_alert stay quiet.
  Map<String, dynamic> okFacts() => {
        'moisture': 'ok',
        'n_band': 'ok',
        'p_band': 'ok',
        'k_band': 'ok',
        'ph_band': 'ok',
        'temp_band': 'ok',
        'ec_band': 'ok',
        'salinity_band': 'ok',
      };

  SoilReading reading({
    required DateTime recordedAt,
    String validationStatus = 'ok',
    String? validationMessage,
  }) {
    return SoilReading(
      id: 'reading-1',
      recordedAt: recordedAt,
      moisturePercent: 42,
      ph: 6.4,
      validationStatus: validationStatus,
      validationMessage: validationMessage,
    );
  }

  group('TC_ALERT_001 device_offline when reading is stale', () {
    test('emits device_offline when latest reading is older than 2h', () {
      final drafts = evaluator.evaluate(
        farmId: farmId,
        reading: reading(recordedAt: now.subtract(const Duration(hours: 3))),
        facts: okFacts(),
        now: now,
      );

      final offline = drafts.where(
        (d) => d.type == FarmNotificationType.deviceOffline,
      );
      expect(offline.length, 1);
      expect(offline.first.severity, FarmNotificationSeverity.urgent);
      expect(offline.first.dedupeKey, 'device_offline:2026-09-17');
      expect(offline.first.title, contains('Sensor has not reported'));
    });
  });

  group('TC_ALERT_002 sensor_error and no false offline', () {
    test('emits sensor_error when validation_status is not ok', () {
      final drafts = evaluator.evaluate(
        farmId: farmId,
        reading: reading(
          recordedAt: now.subtract(const Duration(minutes: 10)),
          validationStatus: 'error',
          validationMessage: 'moisture out of range',
        ),
        facts: okFacts(),
        now: now,
      );

      final errors = drafts.where(
        (d) => d.type == FarmNotificationType.sensorError,
      );
      expect(errors.length, 1);
      expect(errors.first.body, 'moisture out of range');
      expect(errors.first.dedupeKey, 'sensor_error:2026-09-17');
      expect(
        drafts.any((d) => d.type == FarmNotificationType.deviceOffline),
        isFalse,
      );
    });

    test('does not emit device_offline for a fresh in-range reading', () {
      final drafts = evaluator.evaluate(
        farmId: farmId,
        reading: reading(
          recordedAt: now.subtract(const Duration(minutes: 10)),
        ),
        facts: okFacts(),
        now: now,
      );

      expect(
        drafts.any((d) => d.type == FarmNotificationType.deviceOffline),
        isFalse,
      );
      expect(
        drafts.any((d) => d.type == FarmNotificationType.sensorError),
        isFalse,
      );
    });

    test('offline dedupe key is stable for the same Manila day', () {
      final a = evaluator.evaluate(
        farmId: farmId,
        reading: reading(recordedAt: now.subtract(const Duration(hours: 3))),
        facts: okFacts(),
        now: now,
      );
      final b = evaluator.evaluate(
        farmId: farmId,
        reading: reading(recordedAt: now.subtract(const Duration(hours: 4))),
        facts: okFacts(),
        now: now.add(const Duration(hours: 1)),
      );

      final keyA = a
          .firstWhere((d) => d.type == FarmNotificationType.deviceOffline)
          .dedupeKey;
      final keyB = b
          .firstWhere((d) => d.type == FarmNotificationType.deviceOffline)
          .dedupeKey;
      expect(keyA, keyB);
      expect(keyA, 'device_offline:2026-09-17');
    });
  });
}
