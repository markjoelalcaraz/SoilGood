/// Crops care insight client (irrigation, fertilizer, soil) — not catalog scores.
///
/// Crops tab only. Sends crop/phase + classified facts to the Edge Function;
/// the function attaches `prompts.crops.care`. Home has its own today-tip client.
library;

import '../../../core/ai/ai_json_parse.dart';
import '../../../core/ai/groq_chat_client.dart';
import '../../../core/ai/insights_config.dart';
import '../../../core/ai/saved_assessment.dart';
import '../../home/data/soil_reading.dart';
import '../../weather/data/weather_models.dart';
import '../data/planting.dart';
import 'crop_timeline.dart';

/// Calls the insights API for how to maintain the selected crop in this phase.
class CropsCareAiClient {
  CropsCareAiClient({GroqChatClient? chat}) : _chat = chat ?? GroqChatClient();

  final GroqChatClient _chat;

  /// Runs the crops.care job. Caller persists the result.
  Future<({
    String overview,
    double? soilHealthScore,
    List<AiRecommendation> recommendations,
  })>
  generate({
    required InsightsConfig insights,
    required SoilReading reading,
    required Planting planting,
    required CropTimeline timeline,
    WeatherSnapshot? weather,
  }) async {
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
      rainProbToday: weather?.daily.isNotEmpty == true
          ? weather!.daily.first.rainProbability
          : null,
      rainProbTomorrow: (weather?.daily.length ?? 0) > 1
          ? weather!.daily[1].rainProbability
          : null,
      conditionToday: weather?.daily.isNotEmpty == true
          ? weather!.daily.first.conditionLabel
          : null,
    );

    final json = await _chat.completeJson(
      job: 'crops.care',
      userPayload: {
        'crop': planting.crop.name,
        'phase': timeline.current.label,
        'phase_id': timeline.current.id,
        'day_number': timeline.dayNumber,
        'days_to_maturity': timeline.totalDays,
        'days_left': timeline.daysLeft,
        'facts': facts,
      },
    );

    return parseAiInsightJson(
      json,
      allowedTypes: const {'irrigation', 'nutrient', 'soil_management'},
      maxRecommendations: 3,
    );
  }
}
