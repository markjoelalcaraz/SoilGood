/// One claimed ESP32 on the farmer's farm, and the crop plot it watches.
///
/// Profile and the Farm tab use this to list kits by sticker code. A null
/// planting means the kit is on the farm but not on a crop yet. Not a widget.
library;

import '../../home/data/soil_reading.dart';

/// Claimed sensor row plus the latest soil sample, when one exists.
class FarmSensor {
  const FarmSensor({
    required this.id,
    required this.claimCode,
    this.plantingId,
    this.cropName,
    this.plantingStatus,
    this.latest,
  });

  final String id;
  final String claimCode;
  final String? plantingId;
  final String? cropName;
  final String? plantingStatus;
  final SoilReading? latest;

  /// True when this kit is on the farm's current crop.
  bool get onActivePlot =>
      plantingId != null && plantingStatus == 'active' && cropName != null;

  /// Farmer-facing identity. The code matches the sticker on the kit.
  String get label => 'Sensor ($claimCode)';
}
