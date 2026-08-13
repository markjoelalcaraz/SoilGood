/// Home “today” insight client — one urgent action (water, wait, or check sensor).
///
/// Home dashboard only. Sends classified facts to the Edge Function; the
/// function attaches `prompts.home` from insights.json. Not Analytics or Crops.
library;

import '../../../core/ai/ai_json_parse.dart';
import '../../../core/ai/groq_chat_client.dart';
import '../../../core/ai/insights_config.dart';
import '../../../core/ai/saved_assessment.dart';
import '../../weather/data/weather_models.dart';
import '../data/soil_reading.dart';

/// Calls the insights API for today’s irrigation / sensor action.
class HomeAiClient {
  HomeAiClient({GroqChatClient? chat}) : _chat = chat ?? GroqChatClient();

  final GroqChatClient _chat;

  /// Runs the home job. Caller persists the result. No reading → API no_reading.
  Future<({
    String overview,
    double? soilHealthScore,
    List<AiRecommendation> recommendations,
  })>
  generate({
    required InsightsConfig insights,
    required SoilReading reading,
    WeatherSnapshot? weather,
  }) async {
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
      conditionToday: daily.isEmpty ? null : daily.first.conditionLabel,
    );

    final json = await _chat.completeJson(
      job: 'home',
      userPayload: {'facts': facts},
    );

    return parseAiInsightJson(
      json,
      allowedTypes: const {'irrigation'},
      maxRecommendations: 1,
    );
  }
}
