/// Rule-based whole-soil Quick Insight wording for the Home overview banner.
///
/// Logic only — turns classified bands into short farmer English. Not Groq.
/// Used by `_OverallConditionBanner` so farmers see condition in words, not
/// "moisture 28% · N 42".
library;

import '../../../core/ai/crop_band_classify.dart';
import '../data/soil_reading.dart';

/// Builds a short insight sentence from the latest reading.
///
/// Uses [crop] ranges when the reading belongs to a crop plot; universal
/// bands otherwise.
String quickSoilInsight(SoilReading? reading, {CropBandRanges? crop}) {
  if (reading == null) {
    return 'Connect a device to see live soil insights here.';
  }
  if (reading.validationStatus == 'error' ||
      reading.validationStatus == 'warning') {
    return 'Sensor reading looks off. Check the probe before trusting soil advice.';
  }

  final moisture = classifyMoistureBand(
    value: reading.moisturePercent,
    crop: crop,
  );
  final ph = classifyPhBand(value: reading.ph, crop: crop);
  final temp = classifyTempBand(value: reading.soilTemperatureC, crop: crop);
  final salt = classifySalinityBand(value: reading.salinity, crop: crop);

  final parts = <String>[];

  switch (moisture) {
    case 'critical_dry':
      parts.add('Soil is critically dry');
    case 'dry':
      parts.add('Soil is a bit dry');
    case 'critical_wet':
      parts.add('Soil is critically wet');
    case 'wet':
      parts.add('Soil is quite wet');
    case 'ok':
      parts.add('Soil water looks okay');
    case 'missing':
      parts.add('Soil water reading is missing');
    default:
      parts.add('Soil water looks mixed');
  }

  final n = reading.nitrogen;
  final p = reading.phosphorus;
  final k = reading.potassium;
  final lowFood = (n != null && n < 45) ||
      (p != null && p < 20) ||
      (k != null && k < 80);
  if (lowFood) {
    parts.add('plant food looks low');
  } else if (n != null || p != null || k != null) {
    parts.add('plant food looks okay');
  }

  if (ph == 'critical_low' || ph == 'low') {
    parts.add('soil is a bit acidic');
  } else if (ph == 'critical_high' || ph == 'high') {
    parts.add('soil is a bit alkaline');
  }

  if (temp == 'critical_high' || temp == 'high') {
    parts.add('soil is warm');
  } else if (temp == 'critical_low' || temp == 'low') {
    parts.add('soil is cool');
  }

  if (salt == 'high' || salt == 'critical_high') {
    parts.add('salt looks high');
  }

  final body = _joinParts(parts);
  return '$body. Updated ${_formatTime(reading.recordedAt)}.';
}

String _joinParts(List<String> parts) {
  if (parts.isEmpty) return 'Soil looks mixed';
  if (parts.length == 1) return parts.first;
  if (parts.length == 2) return '${parts[0]} and ${parts[1]}';
  final head = parts.sublist(0, parts.length - 1).join(', ');
  return '$head, and ${parts.last}';
}

String _formatTime(DateTime dt) {
  final local = dt.toLocal();
  final h = local.hour.toString().padLeft(2, '0');
  final m = local.minute.toString().padLeft(2, '0');
  return '$h:$m';
}
