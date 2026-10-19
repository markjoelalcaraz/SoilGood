/// In-memory answers from the Add a crop wizard, before a crop is planted.
///
/// Data model only (no Supabase calls). The wizard fills soil + sensor + the
/// sensor's first reading, then hands this to [CropsPage] so crop matches use
/// this plot's own soil and sensor instead of the farm-wide defaults.
library;

import '../../../core/soil/soil_series.dart';
import '../../../core/soil/soil_texture.dart';
import '../../home/data/soil_reading.dart';

/// Soil and sensor of the plot the farmer is about to plant.
class PlotDraft {
  const PlotDraft({
    required this.texture,
    required this.deviceId,
    required this.claimCode,
    required this.reading,
    this.series,
    this.seriesOther,
  });

  /// Always set. From the series' typical feel, or picked when series is unknown.
  final SoilTexture texture;

  /// Curated series, [SoilSeries.other], or null when the farmer is not sure.
  final SoilSeries? series;

  /// Free-text name when [series] is [SoilSeries.other].
  final String? seriesOther;

  final String deviceId;
  final String claimCode;

  /// First fresh reading from the sensor in this plot.
  final SoilReading reading;
}
