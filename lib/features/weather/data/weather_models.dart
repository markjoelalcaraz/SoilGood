/// Data models for Open-Meteo current conditions and short daily forecast rows.
///
/// Used by the weather service and Home forecast card. Pure value types — no
/// network and no widgets in this file.
library;

/// Current + short forecast weather from Open-Meteo.
class WeatherSnapshot {
  const WeatherSnapshot({
    required this.latitude,
    required this.longitude,
    required this.temperatureC,
    required this.humidityPercent,
    required this.weatherCode,
    required this.conditionLabel,
    required this.windSpeedKmh,
    required this.rainfallMm,
    required this.fetchedAt,
    required this.daily,
  });

  final double latitude;
  final double longitude;
  final double temperatureC;
  final double humidityPercent;
  final int weatherCode;
  final String conditionLabel;
  final double windSpeedKmh;
  final double rainfallMm;
  final DateTime fetchedAt;
  final List<DailyForecast> daily;
}

/// One day in the short forecast strip.
class DailyForecast {
  const DailyForecast({
    required this.date,
    required this.weatherCode,
    required this.conditionLabel,
    required this.tempMaxC,
    required this.tempMinC,
    required this.rainProbability,
    required this.rainfallMm,
  });

  final DateTime date;
  final int weatherCode;
  final String conditionLabel;
  final double tempMaxC;
  final double tempMinC;
  final double rainProbability;
  final double rainfallMm;
}
