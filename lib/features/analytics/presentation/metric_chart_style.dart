/// Chart colors and overlay scale for Analytics metric lines.
///
/// Presentation-only. Daily values live on [SoilMetric] / [DailySoilBucket];
/// All-sensors overlay maps each series onto 0–1 using a typical farm range
/// so % and pH can share one chart.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../data/daily_soil_bucket.dart';

/// Line color for one 8-in-1 series (All sensors legend + overlay).
Color metricChartColor(SoilMetric metric) => switch (metric) {
  SoilMetric.moisture => AppColors.primary,
  SoilMetric.ph => AppColors.tertiary,
  SoilMetric.temperature => const Color(0xFFB87A3A),
  SoilMetric.ec => const Color(0xFF3D6B8C),
  SoilMetric.salinity => AppColors.secondary,
  SoilMetric.nitrogen => const Color(0xFF5B7C3A),
  SoilMetric.phosphorus => const Color(0xFF8B6914),
  SoilMetric.potassium => const Color(0xFF6B4F8C),
};

/// Typical visual range so overlay lines share one axis (not raw units).
(double, double) metricOverlayBand(SoilMetric metric) => switch (metric) {
  SoilMetric.moisture => (0, 100),
  SoilMetric.ph => (0, 14),
  SoilMetric.temperature => (10, 40),
  SoilMetric.ec => (0, 4),
  SoilMetric.salinity => (0, 10),
  SoilMetric.nitrogen => (0, 200),
  SoilMetric.phosphorus => (0, 100),
  SoilMetric.potassium => (0, 400),
};

/// 0–1 for overlay, or null when that day has no average.
double? metricOverlayUnit(SoilMetric metric, DailySoilBucket bucket) {
  final v = metric.avgOf(bucket);
  if (v == null) return null;
  final (lo, hi) = metricOverlayBand(metric);
  if (hi == lo) return 0.5;
  return ((v - lo) / (hi - lo)).clamp(0.0, 1.0);
}
