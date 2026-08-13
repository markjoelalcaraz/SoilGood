/// Loads and saves Home / Crops Groq rows in `ai_assessments`.
///
/// Cheap path: latest saved row for this farm + kind (+ planting). Expensive
/// Groq output is inserted only when the page decides to regen.
library;

import '../supabase/supabase_bootstrap.dart';
import 'saved_assessment.dart';

/// Persist / fetch Groq assessments keyed by [kind].
class SavedAssessmentRepository {
  /// Latest saved assessment for [farmId] and [kind], optionally one planting.
  Future<SavedAssessment?> fetchLatest({
    required String farmId,
    required String kind,
    String? plantingId,
  }) async {
    var query = supabase
        .from('ai_assessments')
        .select()
        .eq('farm_id', farmId)
        .eq('kind', kind);
    if (plantingId != null) {
      query = query.eq('planting_id', plantingId);
    }
    final row = await query
        .order('generated_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;

    final recs = await supabase
        .from('ai_recommendations')
        .select()
        .eq('assessment_id', row['id'] as String)
        .order('created_at', ascending: true);

    final list = (recs as List)
        .map(
          (e) =>
              AiRecommendation.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();

    return SavedAssessment.fromJson(row, recommendations: list);
  }

  /// Inserts a new assessment + recommendations. Does not update old rows.
  Future<SavedAssessment> save({
    required String farmId,
    required String kind,
    required String overview,
    required double? soilHealthScore,
    required String modelName,
    required String promptVersion,
    required DateTime validUntil,
    required List<AiRecommendation> recommendations,
    String? plantingId,
    String? soilReadingId,
  }) async {
    final inserted = await supabase
        .from('ai_assessments')
        .insert({
          'farm_id': farmId,
          'kind': kind,
          'planting_id': plantingId,
          'soil_reading_id': soilReadingId,
          'overview': overview,
          'soil_health_score': soilHealthScore,
          'model_name': modelName,
          'prompt_version': promptVersion,
        })
        .select()
        .single();

    final assessmentId = inserted['id'] as String;
    if (recommendations.isNotEmpty) {
      await supabase.from('ai_recommendations').insert(
        recommendations
            .map(
              (r) => {
                'assessment_id': assessmentId,
                'type': r.type,
                'title': r.title,
                'description': r.description,
                'priority': r.priority,
                'recommended_action': r.recommendedAction,
                'valid_until': validUntil.toUtc().toIso8601String(),
              },
            )
            .toList(),
      );
    }

    return SavedAssessment.fromJson(
      inserted,
      recommendations: recommendations
          .map(
            (r) => AiRecommendation(
              type: r.type,
              title: r.title,
              description: r.description,
              recommendedAction: r.recommendedAction,
              priority: r.priority,
              validUntil: validUntil,
            ),
          )
          .toList(),
    );
  }
}
