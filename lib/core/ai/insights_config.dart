/// Loads insights.json once and classifies sensor numbers with local bands.
///
/// Same file the Edge Function uses for Groq slices. Flutter only classifies
/// here (0 tokens). Catalog match scores come from `crops`, not this file.
library;

import 'dart:convert';

import 'package:flutter/services.dart';

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
  }) {
    return {
      'soil_reading_id': soilReadingId,
      'validation': validation,
      'validation_message': ?validationMessage,
      'moisture_pct': moisturePercent,
      'moisture': _band(
        moisturePercent,
        _bands['moisture_pct'] as Map<String, dynamic>?,
        lowKey: 'dry_lt',
        highKey: 'wet_gt',
        lowLabel: 'dry',
        highLabel: 'wet',
      ),
      'ph': ph,
      'ph_band': _band(
        ph,
        _bands['ph'] as Map<String, dynamic>?,
        lowKey: 'low_lt',
        highKey: 'high_gt',
      ),
      'soil_temp_c': soilTemperatureC,
      'temp_band': _band(
        soilTemperatureC,
        _bands['soil_temp_c'] as Map<String, dynamic>?,
        lowKey: 'low_lt',
        highKey: 'high_gt',
      ),
      'ec': ec,
      'ec_band': _band(
        ec,
        _bands['ec_ds_m'] as Map<String, dynamic>?,
        lowKey: 'low_lt',
        highKey: 'high_gt',
      ),
      'salinity_ppt': salinity,
      'salinity_band': _highOnly(
        salinity,
        _bands['salinity_ppt'] as Map<String, dynamic>?,
      ),
      'nitrogen': nitrogen,
      'n_band': _lowOnly(nitrogen, _bands['n_mgkg'] as Map<String, dynamic>?),
      'phosphorus': phosphorus,
      'p_band': _lowOnly(phosphorus, _bands['p_mgkg'] as Map<String, dynamic>?),
      'potassium': potassium,
      'k_band': _lowOnly(potassium, _bands['k_mgkg'] as Map<String, dynamic>?),
      'rain_prob_today': rainProbToday,
      'rain_prob_tomorrow': rainProbTomorrow,
      'condition_today': ?conditionToday,
    };
  }

  String _band(
    double? value,
    Map<String, dynamic>? spec, {
    required String lowKey,
    required String highKey,
    String lowLabel = 'low',
    String highLabel = 'high',
  }) {
    if (value == null || spec == null) return 'missing';
    final low = (spec[lowKey] as num?)?.toDouble();
    final high = (spec[highKey] as num?)?.toDouble();
    if (low != null && value < low) return lowLabel;
    if (high != null && value > high) return highLabel;
    return 'ok';
  }

  String _lowOnly(double? value, Map<String, dynamic>? spec) {
    if (value == null || spec == null) return 'missing';
    final low = (spec['low_lt'] as num?)?.toDouble();
    if (low != null && value < low) return 'low';
    return 'ok';
  }

  String _highOnly(double? value, Map<String, dynamic>? spec) {
    if (value == null || spec == null) return 'missing';
    final high = (spec['high_gt'] as num?)?.toDouble();
    if (high != null && value > high) return 'high';
    return 'ok';
  }
}
