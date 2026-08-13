/// Local cultivation timeline from `planted_at` + catalog `phases`.
///
/// No Groq. The Crops plan view uses this so the farmer can see the current
/// phase and how many days remain until the expected harvest.
library;

import '../../analytics/logic/manila_time.dart';
import '../data/crop_catalog.dart';
import '../data/planting.dart';

/// Computed day/phase/harvest window for one planting.
class CropTimeline {
  const CropTimeline({
    required this.dayNumber,
    required this.totalDays,
    required this.daysLeft,
    required this.harvestDate,
    required this.currentIndex,
    required this.current,
    required this.currentPhaseStart,
    required this.phases,
  });

  final int dayNumber;
  final int totalDays;
  final int daysLeft;
  final DateTime harvestDate;
  final int currentIndex;
  final CropPhase current;
  final DateTime currentPhaseStart;
  final List<CropPhase> phases;
}

/// Builds a timeline, or null when catalog days/phases are missing.
CropTimeline? timelineFor(Planting planting) {
  final planted = planting.plantedAt;
  final crop = planting.crop;
  final total = crop.daysToMaturity;
  if (planted == null || total == null || total <= 0) return null;

  final phases = crop.phases.where((p) => p.days > 0).toList();
  if (phases.isEmpty) return null;

  final today = manilaCalendarDate(DateTime.now());
  final plantedDay = DateTime(planted.year, planted.month, planted.day);
  var dayNumber = today.difference(plantedDay).inDays + 1;
  if (dayNumber < 1) dayNumber = 1;

  final harvestDate =
      planting.expectedHarvestAt ?? plantedDay.add(Duration(days: total));
  var daysLeft = total - dayNumber;
  if (daysLeft < 0) daysLeft = 0;

  var cursor = 1;
  var index = phases.length - 1;
  var phaseStartDay = 1;
  for (var i = 0; i < phases.length; i++) {
    final end = cursor + phases[i].days - 1;
    if (dayNumber <= end || i == phases.length - 1) {
      index = i;
      phaseStartDay = cursor;
      break;
    }
    cursor = end + 1;
  }

  final currentPhaseStart = plantedDay.add(Duration(days: phaseStartDay - 1));

  return CropTimeline(
    dayNumber: dayNumber > total ? total : dayNumber,
    totalDays: total,
    daysLeft: daysLeft,
    harvestDate: DateTime(harvestDate.year, harvestDate.month, harvestDate.day),
    currentIndex: index,
    current: phases[index],
    currentPhaseStart: currentPhaseStart,
    phases: phases,
  );
}
