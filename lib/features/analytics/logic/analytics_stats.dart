/// Period stats computed on the phone from daily soil buckets.
///
/// Used for chart captions (avg/min/max) and compact Groq prompt context.
/// Not a second live 8-in-1 grid — values are labeled for the selected window.
library;

import '../data/daily_soil_bucket.dart';

/// Avg / min / max for one metric across the loaded buckets (days with values).
class MetricPeriodStats {
  const MetricPeriodStats({
    required this.average,
    required this.min,
    required this.max,
    required this.dayCount,
  });

  final double average;
  final double min;
  final double max;
  final int dayCount;
}

/// Dry-day count (inferred): a day whose average moisture is below 30%.
int inferredDryDayCount(List<DailySoilBucket> buckets) {
  var n = 0;
  for (final b in buckets) {
    final m = b.avgMoisture;
    if (m != null && m < 30) n++;
  }
  return n;
}

/// Stats for [metric] from days that have a value. Null if none.
MetricPeriodStats? metricStats(
  List<DailySoilBucket> buckets,
  SoilMetric metric,
) {
  final avgs = <double>[];
  var minV = double.infinity;
  var maxV = -double.infinity;
  for (final b in buckets) {
    final avg = metric.avgOf(b);
    if (avg != null) avgs.add(avg);
    final lo = metric.minOf(b);
    final hi = metric.maxOf(b);
    if (lo != null && lo < minV) minV = lo;
    if (hi != null && hi > maxV) maxV = hi;
  }
  if (avgs.isEmpty) return null;
  final sum = avgs.fold<double>(0, (a, b) => a + b);
  return MetricPeriodStats(
    average: sum / avgs.length,
    min: minV.isFinite ? minV : avgs.reduce((a, b) => a < b ? a : b),
    max: maxV.isFinite ? maxV : avgs.reduce((a, b) => a > b ? a : b),
    dayCount: avgs.length,
  );
}

/// Compact JSON for Groq: daily averages only (not every 15-min row).
Map<String, Object?> bucketsToPromptJson(List<DailySoilBucket> buckets) {
  return {
    'days': buckets
        .map(
          (b) => {
            'date':
                '${b.bucketDate.year.toString().padLeft(4, '0')}-'
                '${b.bucketDate.month.toString().padLeft(2, '0')}-'
                '${b.bucketDate.day.toString().padLeft(2, '0')}',
            'readings': b.readingCount,
            'moisture_pct': b.avgMoisture,
            'ph': b.avgPh,
            'temp_c': b.avgTemp,
            'ec': b.avgEc,
            'salinity_ppt': b.avgSalinity,
            'n_ppm': b.avgNitrogen,
            'p_ppm': b.avgPhosphorus,
            'k_ppm': b.avgPotassium,
          },
        )
        .toList(),
    'inferred_dry_days_moisture_under_30': inferredDryDayCount(buckets),
  };
}

String formatMetric(double value, SoilMetric metric) {
  final n = switch (metric) {
    SoilMetric.moisture || SoilMetric.temperature => value.toStringAsFixed(0),
    SoilMetric.ph || SoilMetric.ec || SoilMetric.salinity =>
      value.toStringAsFixed(1),
    _ => value.toStringAsFixed(0),
  };
  final unit = metric.unit;
  return unit.isEmpty ? n : '$n$unit';
}
