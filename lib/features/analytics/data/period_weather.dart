/// Aggregated Open-Meteo daily weather for one Analytics date window.
///
/// Period rain/temp for the selected timeline — not Home's live current
/// conditions or 3-day forecast strip.
library;

import '../../weather/data/weather_models.dart';

/// Stats + daily rows for the selected Manila Analytics range.
class PeriodWeather {
  const PeriodWeather({required this.days});

  final List<DailyForecast> days;

  double get totalRainMm =>
      days.fold<double>(0, (sum, d) => sum + d.rainfallMm);

  /// Days with at least 1 mm rain (farmer "umulan").
  int get rainyDayCount => days.where((d) => d.rainfallMm >= 1).length;

  double? get avgTempMaxC => _avg(days.map((d) => d.tempMaxC));

  double? get avgTempMinC => _avg(days.map((d) => d.tempMinC));

  /// Compact JSON for Groq — daily rain/temp only, not live Home weather.
  Map<String, Object?> toPromptJson() {
    return {
      'total_rain_mm': double.parse(totalRainMm.toStringAsFixed(1)),
      'rainy_days': rainyDayCount,
      'avg_temp_max_c': avgTempMaxC == null
          ? null
          : double.parse(avgTempMaxC!.toStringAsFixed(1)),
      'avg_temp_min_c': avgTempMinC == null
          ? null
          : double.parse(avgTempMinC!.toStringAsFixed(1)),
      'daily': days
          .map(
            (d) => {
              'date':
                  '${d.date.year.toString().padLeft(4, '0')}-'
                  '${d.date.month.toString().padLeft(2, '0')}-'
                  '${d.date.day.toString().padLeft(2, '0')}',
              'rain_mm': d.rainfallMm,
              'temp_max_c': d.tempMaxC,
              'temp_min_c': d.tempMinC,
            },
          )
          .toList(),
    };
  }

  static double? _avg(Iterable<double> values) {
    final list = values.toList();
    if (list.isEmpty) return null;
    return list.fold<double>(0, (a, b) => a + b) / list.length;
  }
}
