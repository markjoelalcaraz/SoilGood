/// Decides whether Crops should call Groq or reuse saved care insights.
///
/// Pull always loads saved `ai_assessments` (`kind=crops`). The model runs
/// only when there is no row for this planting, the soil reading changed,
/// `valid_until` passed, the phase started after generation, or prompt version changed.
library;

import '../../../core/ai/saved_assessment.dart';
import 'crop_timeline.dart';

/// True when Groq must run for this planting.
bool shouldRegenCropsCareAi({
  required SavedAssessment? saved,
  required String plantingId,
  required String soilReadingId,
  required String promptVersion,
  required CropTimeline timeline,
}) {
  if (saved == null) return true;
  if (saved.plantingId != plantingId) return true;
  if (saved.soilReadingId != soilReadingId) return true;
  if (saved.promptVersion != promptVersion) return true;

  final until = saved.validUntil;
  if (until != null && DateTime.now().isAfter(until)) return true;

  if (saved.generatedAt.isBefore(timeline.currentPhaseStart)) return true;

  return false;
}
