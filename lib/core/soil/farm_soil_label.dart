/// Short farmer-facing label for farm texture + optional series on Crops.
///
/// Used as display-only copy (e.g. `Loam · Bantog`). Not a data model —
/// scoring still uses [SoilTexture] / [SoilSeries] separately.
library;

import 'soil_series.dart';
import 'soil_texture.dart';

/// Builds `Texture · Series` when a curated series is set; else texture only.
///
/// Returns null when both are unset so the UI can hide the row.
String? farmSoilDisplayLabel({
  SoilTexture? texture,
  SoilSeries? series,
}) {
  final seriesLabel =
      (series != null && series.countsForMatch) ? series.label : null;
  final textureLabel = texture?.label;

  if (seriesLabel != null && textureLabel != null) {
    return '$textureLabel · $seriesLabel';
  }
  if (seriesLabel != null) return seriesLabel;
  if (textureLabel != null) return textureLabel;
  return null;
}
