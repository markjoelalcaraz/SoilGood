/// Farmer-facing lines for a sensor that belongs to one crop plot.
///
/// Home, Farm, and alerts share this wording so a low reading is named by
/// sticker code: "Sensor (SG-4K91) area is low". Logic only — no widgets.
library;

import '../../../core/ai/crop_band_classify.dart';
import '../../home/data/soil_reading.dart';

/// How a sensor's latest reading should be called out on Home.
enum SensorAreaFlag { ok, low, veryWet }

/// Dry moisture or low NPK is a low area. Very wet is its own line.
SensorAreaFlag sensorAreaFlag(SoilReading reading) {
  final moisture = classifyMoistureBand(value: reading.moisturePercent);
  if (moisture == 'dry' || moisture == 'critical_dry') {
    return SensorAreaFlag.low;
  }
  if (moisture == 'wet' || moisture == 'critical_wet') {
    return SensorAreaFlag.veryWet;
  }

  final n = reading.nitrogen;
  final p = reading.phosphorus;
  final k = reading.potassium;
  final lowFood = (n != null && n < 45) ||
      (p != null && p < 20) ||
      (k != null && k < 80);
  if (lowFood) return SensorAreaFlag.low;
  return SensorAreaFlag.ok;
}

/// "Tomatoes · Sensor (SG-4K91) area is low" — crop omitted when unknown.
String sensorAreaHeadline({
  required String claimCode,
  required SensorAreaFlag flag,
  String? cropName,
}) {
  final core = switch (flag) {
    SensorAreaFlag.low => 'Sensor ($claimCode) area is low',
    SensorAreaFlag.veryWet => 'Sensor ($claimCode) area is very wet',
    SensorAreaFlag.ok => 'Sensor ($claimCode)',
  };
  final crop = cropName?.trim();
  if (crop == null || crop.isEmpty || flag == SensorAreaFlag.ok) return core;
  return '$crop · $core';
}

/// Short measure under the headline, from the reading that triggered it.
String sensorAreaDetail(SoilReading reading, SensorAreaFlag flag) {
  final moisture = reading.moisturePercent;
  if (moisture != null &&
      (flag == SensorAreaFlag.low || flag == SensorAreaFlag.veryWet)) {
    final shown = moisture == moisture.roundToDouble()
        ? moisture.toStringAsFixed(0)
        : moisture.toStringAsFixed(1);
    return 'Moisture $shown%';
  }
  return 'Check this sensor';
}
