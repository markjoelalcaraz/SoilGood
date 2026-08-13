/// Saved Groq insight row (`ai_assessments` + child `ai_recommendations`).
///
/// Used by Home (`kind=home`) and Crops care (`kind=crops`). Analytics keeps
/// its own [PeriodAssessment] this round.
library;

/// One persisted recommendation under an assessment.
class AiRecommendation {
  const AiRecommendation({
    required this.type,
    required this.title,
    required this.description,
    required this.recommendedAction,
    required this.priority,
    this.validUntil,
  });

  final String type;
  final String title;
  final String description;
  final String recommendedAction;
  final String priority;
  final DateTime? validUntil;

  factory AiRecommendation.fromJson(Map<String, dynamic> json) {
    return AiRecommendation(
      type: json['type'] as String? ?? 'soil_management',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      recommendedAction: json['recommended_action'] as String? ?? '',
      priority: json['priority'] as String? ?? 'medium',
      validUntil: json['valid_until'] == null
          ? null
          : DateTime.tryParse(json['valid_until'] as String),
    );
  }
}

/// One saved Home or Crops Groq assessment.
class SavedAssessment {
  const SavedAssessment({
    required this.id,
    required this.farmId,
    required this.kind,
    required this.overview,
    required this.generatedAt,
    this.plantingId,
    this.soilReadingId,
    this.soilHealthScore,
    this.modelName,
    this.promptVersion,
    this.recommendations = const [],
  });

  final String id;
  final String farmId;
  final String kind;
  final String overview;
  final DateTime generatedAt;
  final String? plantingId;
  final String? soilReadingId;
  final double? soilHealthScore;
  final String? modelName;
  final String? promptVersion;
  final List<AiRecommendation> recommendations;

  /// Earliest `valid_until` among recommendations, if any.
  DateTime? get validUntil {
    DateTime? earliest;
    for (final rec in recommendations) {
      final until = rec.validUntil;
      if (until == null) continue;
      if (earliest == null || until.isBefore(earliest)) earliest = until;
    }
    return earliest;
  }

  factory SavedAssessment.fromJson(
    Map<String, dynamic> json, {
    List<AiRecommendation> recommendations = const [],
  }) {
    return SavedAssessment(
      id: json['id'] as String,
      farmId: json['farm_id'] as String,
      kind: json['kind'] as String? ?? 'home',
      overview: json['overview'] as String? ?? '',
      generatedAt: DateTime.parse(json['generated_at'] as String),
      plantingId: json['planting_id'] as String?,
      soilReadingId: json['soil_reading_id'] as String?,
      soilHealthScore: (json['soil_health_score'] as num?)?.toDouble(),
      modelName: json['model_name'] as String?,
      promptVersion: json['prompt_version'] as String?,
      recommendations: recommendations,
    );
  }
}
