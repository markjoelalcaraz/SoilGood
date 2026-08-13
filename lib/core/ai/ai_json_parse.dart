/// Parses Groq overview + recommendations JSON shared by Home and Crops clients.
///
/// Keeps type/priority allow-lists in one place so page clients stay thin.
library;

import 'groq_chat_client.dart';
import 'saved_assessment.dart';

const _allowedPriority = {'low', 'medium', 'high'};

/// Reads overview, optional score, and recommendation list from Groq JSON.
({
  String overview,
  double? soilHealthScore,
  List<AiRecommendation> recommendations,
})
parseAiInsightJson(
  Map<String, dynamic> json, {
  required Set<String> allowedTypes,
  required int maxRecommendations,
}) {
  final overview = (json['overview'] as String?)?.trim() ?? '';
  if (overview.isEmpty) {
    throw const GroqChatException(
      'Groq JSON missing overview. Pull to try again.',
    );
  }

  final recRaw = json['recommendations'];
  if (recRaw is! List) {
    throw const GroqChatException(
      'Groq JSON missing recommendations list. Pull to try again.',
    );
  }

  final recs = <AiRecommendation>[];
  for (final item in recRaw) {
    if (item is! Map) continue;
    if (recs.length >= maxRecommendations) break;
    final map = Map<String, dynamic>.from(item);
    var type = (map['type'] as String?)?.trim() ?? 'soil_management';
    if (!allowedTypes.contains(type)) {
      type = allowedTypes.first;
    }
    var priority = (map['priority'] as String?)?.trim() ?? 'medium';
    if (!_allowedPriority.contains(priority)) priority = 'medium';
    recs.add(
      AiRecommendation(
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
    throw const GroqChatException(
      'Groq returned no usable recommendations. Pull to try again.',
    );
  }

  return (
    overview: overview,
    soilHealthScore: (json['soil_health_score'] as num?)?.toDouble(),
    recommendations: recs,
  );
}
