/// Home “today” insight client — Condition, Water today, and Nutrients tips.
///
/// Home dashboard only. Sends classified facts (+ optional crop/phase) to the
/// Edge Function; the function attaches `prompts.home` from insights.json.
/// Not Analytics or Crops care.
library;

import '../../../core/ai/ai_json_parse.dart';
import '../../../core/ai/crop_band_classify.dart';
import '../../../core/ai/groq_chat_client.dart';
import '../../../core/ai/insights_config.dart';
import '../../../core/ai/saved_assessment.dart';
import '../../weather/data/weather_models.dart';
import '../data/soil_reading.dart';

/// Calls the insights API for today’s three Home tips.
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
    String? cropName,
    String? phaseId,
    String? phaseLabel,
    CropBandRanges? cropRanges,
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
      airTempC: weather?.temperatureC,
      humidityPct: weather?.humidityPercent,
      windKmh: weather?.windSpeedKmh,
      rainfallMmToday: weather?.rainfallMm,
      conditionTomorrow: daily.length > 1 ? daily[1].conditionLabel : null,
      cropRanges: cropRanges,
    );

    final hasCrop =
        cropName != null && cropName.trim().isNotEmpty && phaseId != null;

    final userPayload = <String, dynamic>{
      'facts': facts,
      if (hasCrop) ...{
        'crop': cropName.trim(),
        'phase': phaseLabel ?? phaseId,
        'phase_id': phaseId,
      },
    };

    final json = await _chat.completeJson(
      job: 'home',
      userPayload: userPayload,
    );

    final allowed = hasCrop
        ? const {'soil_management', 'irrigation', 'nutrient'}
        : const {'soil_management', 'irrigation'};

    return parseAiInsightJson(
      json,
      allowedTypes: allowed,
      maxRecommendations: hasCrop ? 3 : 2,
    );
  }
}
