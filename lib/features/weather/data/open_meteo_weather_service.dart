/// Weather service that calls the free Open-Meteo HTTP API (no API key).
///
/// Home asks this service for current + multi-day forecast using the farm's
/// lat/long. Analytics asks [fetchDailyRange] for the selected date window.
/// Failures are thrown upward so the UI can show them visibly.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'weather_models.dart';

/// Fetches weather from Open-Meteo (free, no API key).
///
/// Docs: https://open-meteo.com/en/docs
class OpenMeteoWeatherService {
  static const _base = 'https://api.open-meteo.com/v1/forecast';

  /// Loads current conditions + next few daily forecasts for a farm pin.
  Future<WeatherSnapshot> fetch({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.parse(_base).replace(
      queryParameters: {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'current': [
          'temperature_2m',
          'relative_humidity_2m',
          'precipitation',
          'weather_code',
          'wind_speed_10m',
        ].join(','),
        'daily': [
          'weather_code',
          'temperature_2m_max',
          'temperature_2m_min',
          'precipitation_sum',
          'precipitation_probability_max',
        ].join(','),
        'timezone': 'auto',
        'forecast_days': '4',
        'wind_speed_unit': 'kmh',
      },
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw StateError(
        'Open-Meteo failed (${response.statusCode}): ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final current = json['current'] as Map<String, dynamic>;
    final daily = json['daily'] as Map<String, dynamic>;

    final times = (daily['time'] as List).cast<String>();
    final codes = (daily['weather_code'] as List).cast<num>();
    final maxes = (daily['temperature_2m_max'] as List).cast<num>();
    final mins = (daily['temperature_2m_min'] as List).cast<num>();
    final rains = (daily['precipitation_sum'] as List).cast<num>();
    final probs = (daily['precipitation_probability_max'] as List).cast<num>();

    final days = <DailyForecast>[];
    for (var i = 0; i < times.length; i++) {
      final code = codes[i].toInt();
      days.add(
        DailyForecast(
          date: DateTime.parse(times[i]),
          weatherCode: code,
          conditionLabel: weatherCodeLabel(code),
          tempMaxC: maxes[i].toDouble(),
          tempMinC: mins[i].toDouble(),
          rainfallMm: rains[i].toDouble(),
          rainProbability: probs[i].toDouble(),
        ),
      );
    }

    final code = (current['weather_code'] as num).toInt();
    return WeatherSnapshot(
      latitude: latitude,
      longitude: longitude,
      temperatureC: (current['temperature_2m'] as num).toDouble(),
      humidityPercent: (current['relative_humidity_2m'] as num).toDouble(),
      weatherCode: code,
      conditionLabel: weatherCodeLabel(code),
      windSpeedKmh: (current['wind_speed_10m'] as num).toDouble(),
      rainfallMm: (current['precipitation'] as num).toDouble(),
      fetchedAt: DateTime.now().toUtc(),
      daily: days,
    );
  }

  /// Daily rain + temp for an inclusive calendar range (Analytics, not Home).
  ///
  /// Uses the forecast API for the last ~90 days (includes today). Older
  /// windows use the archive API. Not current-conditions tiles.
  Future<List<DailyForecast>> fetchDailyRange({
    required double latitude,
    required double longitude,
    required DateTime start,
    required DateTime end,
  }) async {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final startDay = DateTime(start.year, start.month, start.day);
    final useArchive = today.difference(startDay).inDays > 90;
    final base = useArchive
        ? 'https://archive-api.open-meteo.com/v1/archive'
        : _base;

    final uri = Uri.parse(base).replace(
      queryParameters: {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'start_date': _isoDate(start),
        'end_date': _isoDate(end),
        'daily': [
          'weather_code',
          'temperature_2m_max',
          'temperature_2m_min',
          'precipitation_sum',
        ].join(','),
        'timezone': 'Asia/Manila',
      },
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw StateError(
        'Open-Meteo range failed (${response.statusCode}): ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final daily = json['daily'] as Map<String, dynamic>?;
    if (daily == null) {
      throw StateError('Open-Meteo range missing daily block.');
    }

    final times = (daily['time'] as List).cast<String>();
    final codes = daily['weather_code'] as List? ?? const [];
    final maxes = daily['temperature_2m_max'] as List? ?? const [];
    final mins = daily['temperature_2m_min'] as List? ?? const [];
    final rains = daily['precipitation_sum'] as List? ?? const [];

    final days = <DailyForecast>[];
    for (var i = 0; i < times.length; i++) {
      final rain = _numAt(rains, i);
      final tmax = _numAt(maxes, i);
      final tmin = _numAt(mins, i);
      if (rain == null && tmax == null && tmin == null) continue;
      final code = _numAt(codes, i)?.toInt() ?? 0;
      days.add(
        DailyForecast(
          date: DateTime.parse(times[i]),
          weatherCode: code,
          conditionLabel: weatherCodeLabel(code),
          tempMaxC: tmax ?? 0,
          tempMinC: tmin ?? 0,
          rainfallMm: rain ?? 0,
          rainProbability: 0,
        ),
      );
    }
    return days;
  }

  static String _isoDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  static double? _numAt(List<dynamic> list, int i) {
    if (i >= list.length || list[i] == null) return null;
    return (list[i] as num).toDouble();
  }
}

/// Maps WMO weather codes to short farmer-friendly labels.
String weatherCodeLabel(int code) {
  if (code == 0) return 'Clear';
  if (code <= 3) return 'Partly cloudy';
  if (code <= 48) return 'Foggy';
  if (code <= 57) return 'Drizzle';
  if (code <= 67) return 'Rain';
  if (code <= 77) return 'Snow/ice';
  if (code <= 82) return 'Showers';
  if (code <= 99) return 'Thunderstorm';
  return 'Unknown';
}

/// Picks a Material icon for a WMO weather code.
IconData weatherCodeIcon(int code) {
  if (code == 0) return Icons.wb_sunny;
  if (code <= 3) return Icons.wb_cloudy;
  if (code <= 48) return Icons.cloud;
  if (code <= 67) return Icons.grain;
  if (code <= 82) return Icons.umbrella;
  return Icons.thunderstorm;
}
