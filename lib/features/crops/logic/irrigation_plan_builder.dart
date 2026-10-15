/// Rule-based builder for the Crops irrigation week (trend + now + forecast).
///
/// Logic layer only — not UI. Produces day actions without Groq so the plan
/// never defaults to watering every day. Persist via [IrrigationPlanRepository].
library;

import '../../analytics/logic/manila_time.dart';
import '../../home/data/soil_reading.dart';
import '../../weather/data/weather_models.dart';
import '../data/irrigation_plan.dart';

/// Prompt / builder version stamped on saved plans.
const kIrrigationPlanRulesVersion = 'irrigation_rules_v1';

/// Draft slot before DB ids exist.
class IrrigationSlotDraft {
  const IrrigationSlotDraft({
    required this.slotDate,
    required this.action,
    required this.confidence,
    required this.guidance,
    required this.reason,
  });

  final DateTime slotDate;
  final IrrigationSlotAction action;
  final String confidence;
  final String guidance;
  final String reason;
}

/// Builds a rolling horizon from soil + weather (not “water × 7”).
class IrrigationPlanBuilder {
  /// Classified moisture band + rain story + phase for regen skips.
  static String storyFingerprint({
    required String moistureBand,
    required double? dryingPerDay,
    required String rainStory,
    required String? phaseId,
    required String? lastIrrigationManilaDay,
  }) {
    final dry = dryingPerDay?.toStringAsFixed(1) ?? 'na';
    return 'IRFP:$moistureBand|$dry|$rainStory|${phaseId ?? '-'}|${lastIrrigationManilaDay ?? '-'}|$kIrrigationPlanRulesVersion';
  }

  /// Approx moisture drop per day from recent bucket averages (optional).
  static double? dryingPerDay(List<double> recentMoistureNewestLast) {
    if (recentMoistureNewestLast.length < 2) return null;
    final first = recentMoistureNewestLast.first;
    final last = recentMoistureNewestLast.last;
    final days = recentMoistureNewestLast.length - 1;
    if (days <= 0) return null;
    return (first - last) / days;
  }

  /// Rain story token for fingerprint (coarse, avoids tiny wobble regenerates).
  static String rainStoryToken(WeatherSnapshot? weather) {
    final days = weather?.daily ?? const <DailyForecast>[];
    if (days.isEmpty) return 'noraindata';
    final buf = StringBuffer();
    for (var i = 0; i < days.length && i < 7; i++) {
      final p = days[i].rainProbability;
      final bucket = p >= 70
          ? 'H'
          : p >= 40
              ? 'M'
              : 'L';
      buf.write(bucket);
    }
    return buf.toString();
  }

  /// Builds drafts for each forecast day (or 7 empty-check days if no weather).
  List<IrrigationSlotDraft> build({
    required SoilReading reading,
    WeatherSnapshot? weather,
    String? phaseLabel,
    DateTime? lastIrrigationManilaDay,
    double? dryingPerDay,
  }) {
    final today = manilaCalendarDate(DateTime.now());
    final daily = weather?.daily ?? const <DailyForecast>[];
    final horizon = daily.isEmpty ? 7 : daily.length.clamp(1, 7);
    final moisture = reading.moisturePercent;
    final isCriticalDry = moisture != null && moisture < 15;
    final isDry = moisture != null && moisture < 30;
    final isWet = moisture != null && moisture > 85;

    final drafts = <IrrigationSlotDraft>[];
    var daysSinceWater = _daysSince(today, lastIrrigationManilaDay);
    // Prefer at least 1 clear day between waterings unless critically dry.
    const minGap = 2;

    for (var i = 0; i < horizon; i++) {
      final day = DateTime(today.year, today.month, today.day + i);
      final conf = i <= 3 ? 'high' : 'likely';
      final rainProb = i < daily.length ? daily[i].rainProbability : null;
      final rainMm = i < daily.length ? daily[i].rainfallMm : null;

      IrrigationSlotAction action;
      String guidance;
      String reason;

      if (rainProb != null && rainProb >= 60) {
        action = IrrigationSlotAction.noWater;
        guidance = 'Likely no water · rain expected';
        reason = '~${rainProb.round()}% rain';
      } else if (rainMm != null && rainMm >= 5) {
        action = IrrigationSlotAction.noWater;
        guidance = 'Likely no water · rain in forecast';
        reason = '${rainMm.toStringAsFixed(0)} mm forecast';
      } else if (isWet && i == 0) {
        action = IrrigationSlotAction.noWater;
        guidance = 'No water · soil already wet';
        reason = 'Moisture high now';
      } else if (isCriticalDry && i == 0) {
        action = IrrigationSlotAction.water;
        guidance = 'Water today · soil critically dry';
        reason = 'Moisture critically low';
        daysSinceWater = 0;
      } else if (isDry && i == 0) {
        action = IrrigationSlotAction.water;
        guidance = 'Water today · stop when top soil cools';
        reason = dryingPerDay != null && dryingPerDay > 3
            ? 'Soil drying faster than expected'
            : 'Moisture low now';
        daysSinceWater = 0;
      } else if (isDry || (dryingPerDay != null && dryingPerDay > 4)) {
        // Space waterings across the week.
        if (daysSinceWater >= minGap && (rainProb == null || rainProb < 40)) {
          action = IrrigationSlotAction.water;
          guidance = i <= 3
              ? 'Morning water if soil still dry'
              : 'Light water if still dry';
          reason = conf == 'likely'
              ? 'Tentative · farther forecast'
              : 'Dry pattern · spaced watering';
          daysSinceWater = 0;
        } else {
          action = IrrigationSlotAction.check;
          guidance = 'Check soil · water only if dry';
          reason = rainProb != null && rainProb >= 40
              ? '~${rainProb.round()}% rain'
              : 'Between water days';
          daysSinceWater += 1;
        }
      } else {
        action = IrrigationSlotAction.check;
        guidance = 'Check soil · no water planned';
        reason = rainProb != null
            ? '~${rainProb.round()}% rain chance'
            : 'Moisture looks okay';
        daysSinceWater += 1;
      }

      if (phaseLabel != null &&
          phaseLabel.toLowerCase().contains('flower') &&
          action == IrrigationSlotAction.water) {
        guidance = '$guidance · flowering';
      }

      drafts.add(
        IrrigationSlotDraft(
          slotDate: day,
          action: action,
          confidence: conf,
          guidance: guidance,
          reason: reason,
        ),
      );
    }

    return drafts;
  }

  static int _daysSince(DateTime today, DateTime? last) {
    if (last == null) return 99;
    return today.difference(DateTime(last.year, last.month, last.day)).inDays;
  }
}
