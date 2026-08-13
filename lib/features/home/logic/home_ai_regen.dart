/// Decides whether Home should call Groq or reuse the saved today-tip.
///
/// Pull always loads saved `ai_assessments` (`kind=home`). The model runs
/// only when there is no row, `soil_reading_id` changed, `valid_until` passed,
/// or prompt version changed. Realtime sensor updates do not trigger Groq.
library;

import '../../../core/ai/saved_assessment.dart';

/// True when Groq must run for this latest reading.
bool shouldRegenHomeAi({
  required SavedAssessment? saved,
  required String soilReadingId,
  required String promptVersion,
}) {
  if (saved == null) return true;
  if (saved.soilReadingId != soilReadingId) return true;
  if (saved.promptVersion != promptVersion) return true;

  final until = saved.validUntil;
  if (until != null && DateTime.now().isAfter(until)) return true;

  return false;
}
