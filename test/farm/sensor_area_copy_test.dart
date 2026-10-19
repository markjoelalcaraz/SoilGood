/// Wording for a low sensor named by its sticker code.
///
/// Home and alerts both say "Sensor (SG-4K91) area is low" for a dry kit.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:soil_sense/core/ai/crop_band_classify.dart';
import 'package:soil_sense/features/farm/logic/sensor_area_copy.dart';
import 'package:soil_sense/features/home/data/soil_reading.dart';
import 'package:soil_sense/features/notifications/logic/notification_evaluator.dart';

void main() {
  test('dry moisture on a named sensor is a low area', () {
    final reading = SoilReading(
      id: 'r1',
      recordedAt: DateTime.utc(2026, 10, 12),
      moisturePercent: 22,
    );
    expect(sensorAreaFlag(reading), SensorAreaFlag.low);
    expect(
      sensorAreaHeadline(
        claimCode: 'SG-4K91',
        flag: SensorAreaFlag.low,
        cropName: 'Tomatoes',
      ),
      'Tomatoes · Sensor (SG-4K91) area is low',
    );
    expect(sensorAreaDetail(reading, SensorAreaFlag.low), 'Wetness 22%');
  });

  test('wetness inside the crop range is ok, outside follows the range', () {
    const squash = CropBandRanges(moistureMin: 40, moistureMax: 75);
    expect(classifyMoistureBand(value: 60, crop: squash), 'ok');
    expect(classifyMoistureBand(value: 74, crop: squash), 'ok');
    expect(classifyMoistureBand(value: 78, crop: squash), 'wet');
    expect(classifyMoistureBand(value: 100, crop: squash), 'critical_wet');
    const paddy = CropBandRanges(moistureMin: 60, moistureMax: 100);
    expect(classifyMoistureBand(value: 98, crop: paddy), 'ok');
    expect(classifyMoistureBand(value: 98), 'critical_wet');
  });

  test('alert title uses the sticker code and a per-device day key', () {
    const evaluator = NotificationEvaluator();
    final drafts = evaluator.evaluate(
      farmId: 'farm',
      reading: SoilReading(
        id: 'r1',
        deviceId: 'device-b',
        recordedAt: DateTime.utc(2026, 10, 12, 1),
        moisturePercent: 22,
      ),
      facts: {
        'moisture': 'dry',
        'n_band': 'ok',
        'p_band': 'ok',
        'k_band': 'ok',
        'ph_band': 'ok',
        'temp_band': 'ok',
        'ec_band': 'ok',
        'salinity_band': 'ok',
      },
      now: DateTime.utc(2026, 10, 12, 4),
      sensorCode: 'SG-4K91',
      deviceId: 'device-b',
    );
    final water = drafts.singleWhere((d) => d.title.contains('area is low'));
    expect(water.title, 'Sensor (SG-4K91) area is low');
    expect(water.dedupeKey, contains('device-b'));
  });
}
