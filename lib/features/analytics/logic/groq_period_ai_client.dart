/// Analytics period insight client — selected Manila window via the Edge Function.
///
/// Not Home's "water today" tip. Sends daily soil buckets plus period weather;
/// the function attaches `prompts.analytics`. No buckets → no Groq call.
library;

import '../../../core/ai/groq_chat_client.dart';
import '../data/daily_soil_bucket.dart';
import '../data/period_assessment.dart';
import '../data/period_weather.dart';
import 'analytics_period.dart';
import 'analytics_stats.dart';
import 'manila_time.dart';

export '../../../core/ai/groq_chat_client.dart' show kGroqModel;

/// Thrown when the insights API cannot produce a usable period assessment.
class GroqPeriodAiException implements Exception {
  const GroqPeriodAiException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Calls the insights API with daily history JSON and parses recommendations.
class GroqPeriodAiClient {
  GroqPeriodAiClient({GroqChatClient? chat}) : _chat = chat ?? GroqChatClient();

  final GroqChatClient _chat;

  /// Runs the analytics job. Caller persists the result.
  Future<({
    String overview,
    double? soilHealthScore,
    List<PeriodRecommendation> recommendations,
  })>
  generate({
    required AnalyticsPeriod period,
    required List<DailySoilBucket> buckets,
    PeriodWeather? weather,
    String? cropName,
  }) async {
    if (buckets.isEmpty) {
      throw const GroqPeriodAiException(
        'No soil data yet — AI was not called.',
      );
    }

    try {
      final json = await _chat.completeJson(
        job: 'analytics',
        userPayload: {
          'period_label': period.label,
          'period_days': period.dayCount,
          'period_start': manilaIsoDate(period.start),
          'period_end': manilaIsoDate(period.end),
          'crop': cropName,
          'history': bucketsToPromptJson(buckets),
          if (weather != null) 'weather': weather.toPromptJson(),
        },
      );
      return _parseMap(json);
    } on GroqChatException catch (e) {
      throw GroqPeriodAiException(e.message);
    }
  }

  static const _allowedTypes = {
    'irrigation',
    'nutrient',
    'soil_management',
    'crop_suitability',
  };

  static const _allowedPriority = {'low', 'medium', 'high'};

  ({
    String overview,
    double? soilHealthScore,
    List<PeriodRecommendation> recommendations,
  })
  _parseMap(Map<String, dynamic> json) {
    final overview = (json['overview'] as String?)?.trim() ?? '';
    if (overview.isEmpty) {
      throw const GroqPeriodAiException(
        'Insights JSON missing overview. Pull to try again.',
      );
    }

    final recRaw = json['recommendations'];
    if (recRaw is! List) {
      throw const GroqPeriodAiException(
        'Insights JSON missing recommendations list. Pull to try again.',
      );
    }

    final recs = <PeriodRecommendation>[];
    for (final item in recRaw) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      var type = (map['type'] as String?)?.trim() ?? 'soil_management';
      if (!_allowedTypes.contains(type)) type = 'soil_management';
      var priority = (map['priority'] as String?)?.trim() ?? 'medium';
      if (!_allowedPriority.contains(priority)) priority = 'medium';
      recs.add(
        PeriodRecommendation(
          type: type,
          title: (map['title'] as String?)?.trim() ?? 'Action',
          description: (map['description'] as String?)?.trim() ?? '',
          recommendedAction:
              (map['recommended_action'] as String?)?.trim() ?? '',
          priority: priority,
        ),
      );
    }
    if (recs.isEmpty) {
      throw const GroqPeriodAiException(
        'Insights API returned no usable recommendations. Pull to try again.',
      );
    }

    return (
      overview: overview,
      soilHealthScore: (json['soil_health_score'] as num?)?.toDouble(),
      recommendations: recs,
    );
  }
}
