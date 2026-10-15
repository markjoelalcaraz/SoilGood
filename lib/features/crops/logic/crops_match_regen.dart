/// Decides whether Crops list mode should call Groq for catalog match scores.
///
/// Pull always loads saved `ai_assessments` (`kind=crops_match`). The model runs
/// only when there is no row, the soil reading changed, the weather story
/// fingerprint changed, `valid_until` passed, or prompt version changed.
library;

import '../../../core/ai/saved_assessment.dart';
import '../../../core/soil/soil_series.dart';
import '../../../core/soil/soil_texture.dart';
import '../../home/data/soil_reading.dart';
import '../../weather/data/weather_models.dart';
import 'crop_match.dart';

/// Prefix stored on `ai_assessments.overview` for match weather story regen.
const kCropsMatchFpPrefix = 'SGFP:';

/// Compact weather + season + soil story for match regen (0 Groq tokens).
String buildCropsMatchStoryFingerprint({
  required SoilReading reading,
  WeatherSnapshot? weather,
  SoilTexture? farmSoilTexture,
  SoilSeries? farmSoilSeries,
}) {
  final w = buildCropMatchWeatherFacts(weather);
  String n(Object? v) {
    if (v == null) return 'x';
    if (v is num) return v.toStringAsFixed(1);
    return v.toString();
  }

  return [
    farmSoilSeries?.wire ?? 'x',
    farmSoilTexture?.wire ?? 'x',
    reading.validationStatus,
    n(reading.moisturePercent),
    n(reading.ph),
    n(reading.soilTemperatureC),
    n(reading.ec),
    n(reading.salinity),
    n(w['ph_wet_season_now']),
    n(w['air_temp_c']),
    n(w['rain_prob_max_3d']),
    n(w['rain_sum_mm_3d']),
    w['condition_today'] ?? 'x',
  ].join('|');
}

/// Stamps [fingerprint] onto overview for persistence.
String encodeCropsMatchOverview({
  required String fingerprint,
  required String overview,
}) {
  final body = overview.trim();
  return '$kCropsMatchFpPrefix$fingerprint\n$body';
}

/// Splits a saved overview into fingerprint + farmer-facing text.
({String? fingerprint, String overview}) decodeCropsMatchOverview(String raw) {
  final text = raw.trim();
  if (!text.startsWith(kCropsMatchFpPrefix)) {
    return (fingerprint: null, overview: text);
  }
  final nl = text.indexOf('\n');
  if (nl < 0) {
    return (
      fingerprint: text.substring(kCropsMatchFpPrefix.length).trim(),
      overview: '',
    );
  }
  return (
    fingerprint: text.substring(kCropsMatchFpPrefix.length, nl).trim(),
    overview: text.substring(nl + 1).trim(),
  );
}

/// True when Groq must run for catalog match.
bool shouldRegenCropsMatchAi({
  required SavedAssessment? saved,
  required String soilReadingId,
  required String promptVersion,
  required String weatherFingerprint,
}) {
  if (saved == null) return true;
  if (saved.soilReadingId != soilReadingId) return true;
  if (saved.promptVersion != promptVersion) return true;

  final until = saved.validUntil;
  if (until != null && DateTime.now().isAfter(until)) return true;

  final savedFp = decodeCropsMatchOverview(saved.overview).fingerprint;
  if (savedFp == null || savedFp != weatherFingerprint) return true;

  return false;
}
