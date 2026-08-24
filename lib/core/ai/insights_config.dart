/// Loads insights.json once and classifies sensor numbers with local bands.
///
/// Same file the Edge Function uses for Groq slices. Flutter only classifies
/// here (0 tokens). When [CropBandRanges] is passed, moisture/temp/pH/EC/salt
/// use crop baselines + phase overlays; NPK stays universal low-only.
library;

import 'dart:convert';

import 'package:flutter/services.dart';

import 'crop_band_classify.dart';

/// Local insight rules + band classifier. 0 Groq tokens to load.
class InsightsConfig {
  InsightsConfig._({
    required this.promptVersion,
    required this.raw,
    required this.homeCacheHours,
    required this.cropsCacheHours,
    required this.skipIfRainProbPctGte,
  });

  final String promptVersion;
  final Map<String, dynamic> raw;
  final int homeCacheHours;
  final int cropsCacheHours;
  final double skipIfRainProbPctGte;

  static InsightsConfig? _cached;

  /// Loads the asset once per process.
  static Future<InsightsConfig> load() async {
    if (_cached != null) return _cached!;
    final text = await rootBundle.loadString(
      'supabase/functions/soilgood-insights/insights.json',
    );
    final json = jsonDecode(text) as Map<String, dynamic>;
    final cache = json['cache_hours'] as Map<String, dynamic>? ?? {};
    final irrigation = json['irrigation'] as Map<String, dynamic>? ?? {};
    _cached = InsightsConfig._(
      promptVersion: json['prompt_version'] as String? ?? 'insights_v1',
      raw: json,
      homeCacheHours: (cache['home'] as num?)?.toInt() ?? 12,
      cropsCacheHours: (cache['crops'] as num?)?.toInt() ?? 12,
      skipIfRainProbPctGte:
          (irrigation['skip_if_rain_prob_pct_gte'] as num?)?.toDouble() ?? 60,
    );
    return _cached!;
  }

  Map<String, dynamic> get _bands =>
      (raw['bands'] as Map<String, dynamic>?) ?? {};

  /// Compact slice Groq is allowed to see for [pageKey] (`home` or `crops.care`).
  Map<String, dynamic> promptSlice(String pageKey) {
    final prompts = raw['prompts'] as Map<String, dynamic>? ?? {};
    Object? pagePrompt = prompts;
    for (final part in pageKey.split('.')) {
      if (pagePrompt is! Map) {
        pagePrompt = null;
        break;
      }
      pagePrompt = pagePrompt[part];
    }
    return {
      'voice': raw['voice'],
      'output': raw['output'],
      'bands': raw['bands'],
      'irrigation': raw['irrigation'],
      'prompt': pagePrompt,
    };
  }

  /// Classified latest reading + optional forecast rain probs. No invented numbers.
  ///
  /// Pass [cropRanges] when an active planting exists so moisture/temp/pH/EC/salt
  /// use crop + phase overlays. Omit for universal bands + extreme floors.
  Map<String, dynamic> classifiedFacts({
    required String soilReadingId,
    required String validation,
    String? validationMessage,
    double? moisturePercent,
    double? ph,
    double? soilTemperatureC,
    double? ec,
    double? salinity,
    double? nitrogen,
    double? phosphorus,
    double? potassium,
    double? rainProbToday,
    double? rainProbTomorrow,
    String? conditionToday,
    double? airTempC,
    double? humidityPct,
    double? windKmh,
    double? rainfallMmToday,
    String? conditionTomorrow,
    CropBandRanges? cropRanges,
  }) {
    final moisture = classifyMoistureBand(
      value: moisturePercent,
      crop: cropRanges,
    );
    final tempBand = classifyTempBand(
      value: soilTemperatureC,
      crop: cropRanges,
    );
    final phBand = classifyPhBand(value: ph, crop: cropRanges);
    final ecBand = classifyEcBand(value: ec, crop: cropRanges);
    final salinityBand = classifySalinityBand(
      value: salinity,
      crop: cropRanges,
    );

    return {
      'soil_reading_id': soilReadingId,
      'validation': validation,
      'validation_message': ?validationMessage,
      'moisture_pct': moisturePercent,
      'moisture': moisture,
      'ph': ph,
      'ph_band': phBand,
      'soil_temp_c': soilTemperatureC,
      'temp_band': tempBand,
      'ec': ec,
      'ec_band': ecBand,
      'salinity_ppt': salinity,
      'salinity_band': salinityBand,
      'nitrogen': nitrogen,
      'n_band': _lowOnly(nitrogen, _bands['n_mgkg'] as Map<String, dynamic>?),
      'phosphorus': phosphorus,
      'p_band': _lowOnly(phosphorus, _bands['p_mgkg'] as Map<String, dynamic>?),
      'potassium': potassium,
      'k_band': _lowOnly(potassium, _bands['k_mgkg'] as Map<String, dynamic>?),
      'rain_prob_today': rainProbToday,
      'rain_prob_tomorrow': rainProbTomorrow,
      'condition_today': ?conditionToday,
      'air_temp_c': airTempC,
      'humidity_pct': humidityPct,
      'wind_kmh': windKmh,
      'rainfall_mm_today': rainfallMmToday,
      'condition_tomorrow': ?conditionTomorrow,
      if (cropRanges != null) 'crop_ranges_fp': cropRanges.fingerprintToken(),
    };
  }

  String _lowOnly(double? value, Map<String, dynamic>? spec) {
    if (value == null || spec == null) return 'missing';
    final low = (spec['low_lt'] as num?)?.toDouble();
    if (low != null && value < low) return 'low';
    return 'ok';
  }
}
