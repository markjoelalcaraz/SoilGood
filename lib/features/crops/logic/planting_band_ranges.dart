/// Logic helper that picks the crop range a soil reading should be judged by.
///
/// Home, the Farm tab, and the Home crop picker use it so "Needs water",
/// Low/High chips, and "area is low/very wet" follow the crop planted where
/// each sensor sits (with its current phase), not one universal cut-off.
library;

import '../../../core/ai/crop_band_classify.dart';
import '../../farm/data/farm_sensor.dart';
import '../data/planting.dart';
import 'crop_timeline.dart';

/// Catalog range for [planting] at its current growth phase.
CropBandRanges plantingBandRanges(Planting planting) =>
    CropBandRanges.fromCrop(
      planting.crop,
      phaseId: timelineFor(planting)?.current.id,
    );

/// Range of the active crop plot [sensor] is on; null when it has no plot.
CropBandRanges? sensorBandRanges(
  FarmSensor sensor,
  List<Planting> plantings,
) {
  if (!sensor.onActivePlot) return null;
  for (final planting in plantings) {
    if (planting.id == sensor.plantingId) return plantingBandRanges(planting);
  }
  return null;
}
