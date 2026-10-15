/// Crops catalog match AI client — grounded suitability scores (not care chores).
///
/// Crops list mode only (no planting). Sends per-crop facts built locally; the
/// Edge Function attaches `prompts.crops.match`. Care stays on `crops.care`.
library;

import '../../../core/ai/groq_chat_client.dart';
import '../../../core/ai/insights_config.dart';
import '../../../core/ai/saved_assessment.dart';
import '../../../core/soil/soil_series.dart';
import '../../../core/soil/soil_texture.dart';
import '../../home/data/soil_reading.dart';
import '../../weather/data/weather_models.dart';
import '../data/crop_catalog.dart';
import 'crop_match.dart';

/// Calls the insights API to rank catalog crops from grounded facts.
class CropsMatchAiClient {
  CropsMatchAiClient({GroqChatClient? chat}) : _chat = chat ?? GroqChatClient();

  final GroqChatClient _chat;

  /// Runs `crops.match`. Caller stamps fingerprint + persists.
  Future<({
    String overview,
    List<AiRecommendation> recommendations,
  })> generate({
    required InsightsConfig insights,
    required SoilReading reading,
    required List<CropCatalogEntry> catalog,
    WeatherSnapshot? weather,
    SoilTexture? farmSoilTexture,
    SoilSeries? farmSoilSeries,
  }) async {
    final catalogFacts = buildCropMatchCatalogFacts(
      reading: reading,
      catalog: catalog,
      weather: weather,
      farmSoilTexture: farmSoilTexture,
      farmSoilSeries: farmSoilSeries,
    );
    if (catalogFacts.isEmpty) {
      throw const GroqChatException(
        'No catalog ranges to match. Check crops table ranges.',
      );
    }

    final allowedIds = {
      for (final row in catalogFacts) row['crop_id'] as String,
    };
    final byId = {for (final c in catalog) c.id: c};

    final json = await _chat.completeJson(
      job: 'crops.match',
      userPayload: {
        'facts': {
          'soil_reading_id': reading.id,
          'validation': reading.validationStatus,
          'validation_message': reading.validationMessage,
          'moisture_percent': reading.moisturePercent,
          'ph': reading.ph,
          'soil_temperature_c': reading.soilTemperatureC,
          'ec': reading.ec,
          'salinity': reading.salinity,
          'nitrogen': reading.nitrogen,
          'phosphorus': reading.phosphorus,
          'potassium': reading.potassium,
          'farm_soil_texture': farmSoilTexture?.wire,
          'farm_soil_series': farmSoilSeries?.wire,
        },
        'weather': buildCropMatchWeatherFacts(weather),
        'catalog': catalogFacts,
      },
    );

    return parseCropsMatchJson(
      json,
      allowedIds: allowedIds,
      catalogById: byId,
    );
  }
}

/// Parses Groq match JSON into persistable recommendations.
({
  String overview,
  List<AiRecommendation> recommendations,
}) parseCropsMatchJson(
  Map<String, dynamic> json, {
  required Set<String> allowedIds,
  required Map<String, CropCatalogEntry> catalogById,
}) {
  final overview = (json['overview'] as String?)?.trim() ?? '';
  if (overview.isEmpty) {
    throw const GroqChatException(
      'Groq JSON missing overview. Pull to try again.',
    );
  }

  final raw = json['matches'];
  if (raw is! List) {
    throw const GroqChatException(
      'Groq JSON missing matches list. Pull to try again.',
    );
  }

  final recs = <AiRecommendation>[];
  final seen = <String>{};
  for (final item in raw) {
    if (item is! Map) continue;
    final map = Map<String, dynamic>.from(item);
    final cropId = (map['crop_id'] as String?)?.trim() ?? '';
    if (cropId.isEmpty || !allowedIds.contains(cropId) || seen.contains(cropId)) {
      continue;
    }
    seen.add(cropId);
    final crop = catalogById[cropId];
    if (crop == null) continue;

    var score = (map['score'] as num?)?.round() ?? -1;
    if (score < 0) score = 0;
    if (score > 100) score = 100;

    final reason = (map['reason'] as String?)?.trim() ?? '';
    if (reason.isEmpty) continue;

    final priority = score >= 80
        ? 'high'
        : score >= kSuitableMatchPercent
            ? 'medium'
            : 'low';

    recs.add(
      AiRecommendation(
        type: 'crop_suitability',
        title: crop.name,
        description: reason,
        recommendedAction: '$cropId|$score',
        priority: priority,
      ),
    );
  }

  if (recs.isEmpty) {
    throw const GroqChatException(
      'Groq returned no usable crop matches. Pull to try again.',
    );
  }

  recs.sort((a, b) {
    final sa = _scoreFromAction(a.recommendedAction);
    final sb = _scoreFromAction(b.recommendedAction);
    return sb.compareTo(sa);
  });

  return (overview: overview, recommendations: recs);
}

/// Maps saved match recommendations back to [CropMatch] cards.
List<CropMatch> cropMatchesFromAssessment({
  required SavedAssessment assessment,
  required List<CropCatalogEntry> catalog,
}) {
  final byId = {for (final c in catalog) c.id: c};
  final out = <CropMatch>[];
  for (final rec in assessment.recommendations) {
    if (rec.type != 'crop_suitability') continue;
    final parsed = _parseAction(rec.recommendedAction);
    if (parsed == null) continue;
    final crop = byId[parsed.cropId];
    if (crop == null) continue;
    out.add(
      CropMatch(
        crop: crop,
        percent: parsed.score,
        reason: rec.description,
      ),
    );
  }
  out.sort((a, b) => b.percent.compareTo(a.percent));
  return suitableMatches(out);
}

int _scoreFromAction(String action) => _parseAction(action)?.score ?? 0;

({String cropId, int score})? _parseAction(String action) {
  final parts = action.split('|');
  if (parts.length != 2) return null;
  final score = int.tryParse(parts[1].trim());
  final id = parts[0].trim();
  if (id.isEmpty || score == null) return null;
  return (cropId: id, score: score.clamp(0, 100));
}
