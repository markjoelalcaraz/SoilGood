/// Decides whether Analytics should call Groq or reuse the saved period AI.
///
/// Pull always loads saved `ai_assessments` for the selected Manila window.
/// The model runs only when that start/end has no row, `valid_until` passed,
/// prompt version changed, or a newer daily bucket exists since generation.
library;

import '../data/daily_soil_bucket.dart';
import '../data/period_assessment.dart';
import 'analytics_period.dart';
import 'manila_time.dart';

const kPeriodAiPromptVersion = 'insights_v1';

/// True when Groq must run for this farm window.
bool shouldRegenPeriodAi({
  required PeriodAssessment? saved,
  required AnalyticsPeriod period,
  required List<DailySoilBucket> buckets,
}) {
  if (buckets.isEmpty) return false;
  if (saved == null) return true;
  final start = saved.periodStart;
  final end = saved.periodEnd;
  if (start == null || end == null) return true;
  if (!sameManilaDay(start, period.start) || !sameManilaDay(end, period.end)) {
    return true;
  }
  if (saved.promptVersion != kPeriodAiPromptVersion) return true;

  final until = saved.validUntil;
  if (until != null && DateTime.now().isAfter(until)) return true;

  final last = buckets.last.bucketDate;
  final generatedDay = manilaCalendarDate(saved.generatedAt);
  if (last.isAfter(generatedDay)) return true;

  return false;
}
