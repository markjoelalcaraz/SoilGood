/// Loads and saves Analytics period AI rows in `ai_assessments`.
///
/// Cheap path: latest saved assessment for this farm + Manila window
/// (`period_start` / `period_end`). Groq is inserted only when the page
/// decides to regen for that exact range.
library;

import '../../../core/supabase/supabase_bootstrap.dart';
import '../logic/manila_time.dart';
import 'period_assessment.dart';

/// Persist / fetch Groq period assessments for the signed-in farmer.
class PeriodAiRepository {
  /// Latest saved assessment for [farmId] and this date window, or null.
  Future<PeriodAssessment?> fetchLatest({
    required String farmId,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    final row = await supabase
        .from('ai_assessments')
        .select()
        .eq('farm_id', farmId)
        .eq('kind', 'analytics')
        .eq('period_start', manilaIsoDate(periodStart))
        .eq('period_end', manilaIsoDate(periodEnd))
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
          (e) => PeriodRecommendation.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();

    return PeriodAssessment.fromJson(row, recommendations: list);
  }

  /// Inserts a new assessment + recommendations. Does not update old rows.
  Future<PeriodAssessment> save({
    required String farmId,
    required DateTime periodStart,
    required DateTime periodEnd,
    required int periodDays,
    required String overview,
    required double? soilHealthScore,
    required String modelName,
    required String promptVersion,
    required DateTime validUntil,
    required List<PeriodRecommendation> recommendations,
  }) async {
    final inserted = await supabase
        .from('ai_assessments')
        .insert({
          'farm_id': farmId,
          'kind': 'analytics',
          'period_days': periodDays,
          'period_start': manilaIsoDate(periodStart),
          'period_end': manilaIsoDate(periodEnd),
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

    return PeriodAssessment.fromJson(
      inserted,
      recommendations: recommendations
          .map(
            (r) => PeriodRecommendation(
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
