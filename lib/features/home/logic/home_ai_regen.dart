/// Decides whether Home should call Groq or reuse the saved tips.
///
/// Open, pull, and Realtime soil updates all load saved `ai_assessments`
/// (`kind=home`) through this gate. The model runs only when there is no row,
/// the story fingerprint changed (bands + rain advice + crop/phase),
/// `valid_until` passed, or prompt version changed. A new `soil_reading_id`
/// alone is not enough when the story is the same — so ~15-min inserts do not
/// burn Groq tokens while Home is open.
library;

import '../../../core/ai/saved_assessment.dart';
import 'home_ai_story.dart';

/// True when Groq must run for this Home story.
bool shouldRegenHomeAi({
  required SavedAssessment? saved,
  required String promptVersion,
  required String currentFingerprint,
}) {
  if (saved == null) return true;
  if (saved.promptVersion != promptVersion) return true;

  final until = saved.validUntil;
  if (until != null && DateTime.now().isAfter(until)) return true;

  final savedFp = savedHomeStoryFingerprint(saved);
  // Old rows without a stamp: regenerate once so we can stamp the fingerprint.
  if (savedFp == null || savedFp.isEmpty) return true;
  if (savedFp != currentFingerprint) return true;

  return false;
}
