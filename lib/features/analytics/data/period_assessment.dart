/// Saved Analytics period AI (kalagayan + soil/crop actions) from Supabase.
///
/// Maps `ai_assessments` + child `ai_recommendations` for one Manila date
/// window (`period_start`–`period_end`). Not Home's latest-reading tip.
library;

/// One Groq recommendation persisted for the Analytics period.
class PeriodRecommendation {
  const PeriodRecommendation({
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

  factory PeriodRecommendation.fromJson(Map<String, dynamic> json) {
    return PeriodRecommendation(
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

/// Period overview + actions for one farm and one selected date window.
class PeriodAssessment {
  const PeriodAssessment({
    required this.id,
    required this.farmId,
    required this.periodDays,
    required this.overview,
    required this.generatedAt,
    this.periodStart,
    this.periodEnd,
    this.soilHealthScore,
    this.modelName,
    this.promptVersion,
    this.recommendations = const [],
  });

  final String id;
  final String farmId;
  final int periodDays;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final String overview;
  final DateTime generatedAt;
  final double? soilHealthScore;
  final String? modelName;
  final String? promptVersion;
  final List<PeriodRecommendation> recommendations;

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

  factory PeriodAssessment.fromJson(
    Map<String, dynamic> json, {
    List<PeriodRecommendation> recommendations = const [],
  }) {
    return PeriodAssessment(
      id: json['id'] as String,
      farmId: json['farm_id'] as String,
      periodDays: (json['period_days'] as num?)?.toInt() ?? 7,
      periodStart: _parseDate(json['period_start']),
      periodEnd: _parseDate(json['period_end']),
      overview: json['overview'] as String? ?? '',
      generatedAt: DateTime.parse(json['generated_at'] as String),
      soilHealthScore: (json['soil_health_score'] as num?)?.toDouble(),
      modelName: json['model_name'] as String?,
      promptVersion: json['prompt_version'] as String?,
      recommendations: recommendations,
    );
  }

  static DateTime? _parseDate(Object? raw) {
    if (raw == null) return null;
    if (raw is DateTime) {
      return DateTime(raw.year, raw.month, raw.day);
    }
    final text = raw.toString();
    final parts = text.split('-');
    if (parts.length < 3) return null;
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2].substring(0, 2)),
    );
  }
}
