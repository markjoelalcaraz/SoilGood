/// Builds and compares the Home AI “story fingerprint” for smarter regen.
///
/// Classifies bands + rain advice + crop/phase locally (0 Groq tokens). Home
/// skips the model when this story matches the fingerprint stamped on the
/// saved assessment, even if a new ESP32 row arrived. Includes temp_band and
/// crop range identity so severity / catalog changes force regen.
library;

import '../../../core/ai/crop_band_classify.dart';
import '../../../core/ai/insights_config.dart';
import '../../../core/ai/saved_assessment.dart';
import '../../weather/data/weather_models.dart';
import '../data/soil_reading.dart';

/// Prefix stored on `ai_assessments.overview` so we can reload the fingerprint
/// without a new DB column. Home UI strips this line before display.
const kHomeStoryFpPrefix = 'SGFP:';

/// Rain bucket used in the Home story (not raw percent).
String homeRainAdviceLabel({
  required InsightsConfig insights,
  double? rainProbToday,
  double? rainProbTomorrow,
}) {
  final today = rainProbToday ?? 0;
  final tomorrow = rainProbTomorrow ?? 0;
  final max = today > tomorrow ? today : tomorrow;
  if (max >= insights.skipIfRainProbPctGte) return 'rain_likely';
  return 'rain_unlikely';
}

/// Compact story string: bands + rain + crop/phase + crop range token.
String buildHomeStoryFingerprint({
  required InsightsConfig insights,
  required SoilReading reading,
  WeatherSnapshot? weather,
  String? cropName,
  String? phaseId,
  CropBandRanges? cropRanges,
}) {
  final daily = weather?.daily ?? const <DailyForecast>[];
  final facts = insights.classifiedFacts(
    soilReadingId: reading.id,
    validation: reading.validationStatus,
    validationMessage: reading.validationMessage,
    moisturePercent: reading.moisturePercent,
    ph: reading.ph,
    soilTemperatureC: reading.soilTemperatureC,
    ec: reading.ec,
    salinity: reading.salinity,
    nitrogen: reading.nitrogen,
    phosphorus: reading.phosphorus,
    potassium: reading.potassium,
    rainProbToday: daily.isEmpty ? null : daily.first.rainProbability,
    rainProbTomorrow: daily.length > 1 ? daily[1].rainProbability : null,
    cropRanges: cropRanges,
  );

  final rain = homeRainAdviceLabel(
    insights: insights,
    rainProbToday: facts['rain_prob_today'] as double?,
    rainProbTomorrow: facts['rain_prob_tomorrow'] as double?,
  );

  final validation = (facts['validation'] as String?)?.trim().isNotEmpty == true
      ? facts['validation'] as String
      : 'unknown';

  return [
    validation,
    facts['moisture'] ?? 'missing',
    facts['temp_band'] ?? 'missing',
    facts['ph_band'] ?? 'missing',
    facts['ec_band'] ?? 'missing',
    facts['n_band'] ?? 'missing',
    facts['p_band'] ?? 'missing',
    facts['k_band'] ?? 'missing',
    facts['salinity_band'] ?? 'missing',
    rain,
    (cropName == null || cropName.trim().isEmpty) ? 'none' : cropName.trim(),
    (phaseId == null || phaseId.trim().isEmpty) ? 'none' : phaseId.trim(),
    facts['crop_ranges_fp'] ?? 'none',
  ].join('|');
}

/// Stamps [fingerprint] onto overview for persistence.
String encodeHomeOverviewWithFingerprint({
  required String fingerprint,
  required String overview,
}) {
  final body = overview.trim();
  return '$kHomeStoryFpPrefix$fingerprint\n$body';
}

/// Splits a saved overview into fingerprint + farmer-facing text.
({String? fingerprint, String overview}) decodeHomeOverview(String raw) {
  final text = raw.trim();
  if (!text.startsWith(kHomeStoryFpPrefix)) {
    return (fingerprint: null, overview: text);
  }
  final nl = text.indexOf('\n');
  if (nl < 0) {
    return (
      fingerprint: text.substring(kHomeStoryFpPrefix.length).trim(),
      overview: '',
    );
  }
  return (
    fingerprint: text.substring(kHomeStoryFpPrefix.length, nl).trim(),
    overview: text.substring(nl + 1).trim(),
  );
}

/// Farmer-facing overview (no SGFP line).
String displayHomeOverview(SavedAssessment assessment) {
  return decodeHomeOverview(assessment.overview).overview;
}

/// Fingerprint from a saved Home row, if stamped.
String? savedHomeStoryFingerprint(SavedAssessment assessment) {
  return decodeHomeOverview(assessment.overview).fingerprint;
}
