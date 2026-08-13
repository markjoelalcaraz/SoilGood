/// Local catalog match: latest 8-in-1 soil snapshot plus current weather.
///
/// No Groq. Null ranges, null readings, and missing weather are skipped so a
/// missing column does not invent a score. Used only when no crop is selected.
library;

import '../../analytics/logic/manila_time.dart';
import '../../home/data/soil_reading.dart';
import '../../weather/data/weather_models.dart';
import '../data/crop_catalog.dart';

/// Minimum percent in-range to show as “suitable”.
const kSuitableMatchPercent = 50;

/// Wet-season crop wants rain likely in the next few days.
const _kWetRainProbMin = 40.0;

/// Dry-preferring crop fails when the short forecast is this wet.
const _kDryRainProbMax = 80.0;
const _kDryRainSumMaxMm = 40.0;

/// One catalog crop scored against the latest reading and optional forecast.
class CropMatch {
  const CropMatch({
    required this.crop,
    required this.percent,
    required this.reason,
  });

  final CropCatalogEntry crop;
  final int percent;
  final String reason;
}

/// How a crop relates to Philippine wet/dry weather.
enum CropRainFit { wet, dry, any }

/// Scores [catalog] against [reading] and optional [weather], highest first.
List<CropMatch> scoreCropMatches({
  required SoilReading reading,
  required List<CropCatalogEntry> catalog,
  WeatherSnapshot? weather,
}) {
  final matches = <CropMatch>[];
  for (final crop in catalog) {
    final scored = _scoreOne(reading, crop, weather);
    if (scored != null) matches.add(scored);
  }
  matches.sort((a, b) => b.percent.compareTo(a.percent));
  return matches;
}

/// Suitable subset (at/above [kSuitableMatchPercent]).
List<CropMatch> suitableMatches(List<CropMatch> all) =>
    all.where((m) => m.percent >= kSuitableMatchPercent).toList();

CropMatch? _scoreOne(
  SoilReading reading,
  CropCatalogEntry crop,
  WeatherSnapshot? weather,
) {
  final rainFit = rainFitFromSeason(crop.growingSeason);
  final checks = <({String label, bool? inRange})>[
    (
      label: 'moisture',
      inRange: _inRange(
        reading.moisturePercent,
        crop.moistureMin,
        crop.moistureMax,
      ),
    ),
    (
      label: 'pH',
      inRange: _inRange(reading.ph, crop.phMin, crop.phMax),
    ),
    (
      label: 'temperature',
      inRange: _inRange(
        reading.soilTemperatureC,
        crop.temperatureMinC,
        crop.temperatureMaxC,
      ),
    ),
    (
      label: 'EC',
      inRange: _inRange(reading.ec, crop.ecMin, crop.ecMax),
    ),
    (
      label: 'salinity',
      inRange: _inRange(reading.salinity, crop.salinityMin, crop.salinityMax),
    ),
    (
      label: 'N',
      inRange: _inRange(reading.nitrogen, crop.nitrogenMin, crop.nitrogenMax),
    ),
    (
      label: 'P',
      inRange: _inRange(reading.phosphorus, crop.phosphorusMin, crop.phosphorusMax),
    ),
    (
      label: 'K',
      inRange: _inRange(reading.potassium, crop.potassiumMin, crop.potassiumMax),
    ),
    (
      label: 'season',
      inRange: _seasonFits(rainFit),
    ),
    (
      label: 'rain',
      inRange: _rainFits(weather, rainFit),
    ),
    (
      label: 'air temperature',
      inRange: _inRange(
        _airTempC(weather),
        crop.temperatureMinC,
        crop.temperatureMaxC,
      ),
    ),
  ];

  final considered = checks.where((c) => c.inRange != null).toList();
  if (considered.isEmpty) return null;

  final ok = considered
      .where((c) => c.inRange == true)
      .map((c) => c.label)
      .toList();
  final bad = considered
      .where((c) => c.inRange == false)
      .map((c) => c.label)
      .toList();
  final percent = ((ok.length / considered.length) * 100).round();

  final weatherLabels = {'season', 'rain', 'air temperature'};
  final usedWeather = considered.any((c) => weatherLabels.contains(c.label));

  final String reason;
  if (bad.isEmpty) {
    reason = usedWeather
        ? 'Soil and weather fit ${crop.name} on this snapshot.'
        : '${ok.join(', ')} fit ${crop.name} on this snapshot.';
  } else if (bad.length == considered.length) {
    reason =
        'This snapshot sits outside ${crop.name} ranges (${bad.join(', ')}).';
  } else {
    reason =
        '${ok.join(', ')} fit; ${bad.join(', ')} outside ${crop.name} range.';
  }

  return CropMatch(crop: crop, percent: percent, reason: reason);
}

/// Wet / dry / any from catalog `growing_season` text.
CropRainFit rainFitFromSeason(String? growingSeason) {
  final s = growingSeason?.toLowerCase() ?? '';
  if (s.isEmpty) return CropRainFit.any;
  final wet = s.contains('wet');
  final dry = s.contains('dry');
  if (s.contains('year') || (wet && dry)) return CropRainFit.any;
  if (wet) return CropRainFit.wet;
  if (dry) return CropRainFit.dry;
  return CropRainFit.any;
}

/// Philippine wet season is June–November (Manila calendar).
bool isPhWetSeason([DateTime? instant]) {
  final month = manilaCalendarDate(instant ?? DateTime.now()).month;
  return month >= 6 && month <= 11;
}

/// Null when the crop is year-round / mixed so season does not change the score.
bool? _seasonFits(CropRainFit fit) {
  if (fit == CropRainFit.any) return null;
  final wetNow = isPhWetSeason();
  if (fit == CropRainFit.wet) return wetNow;
  return !wetNow;
}

/// Null when weather is missing or the crop has no rain preference.
bool? _rainFits(WeatherSnapshot? weather, CropRainFit fit) {
  if (weather == null || fit == CropRainFit.any) return null;
  final days = weather.daily.take(3);
  var maxProb = 0.0;
  var rainSum = 0.0;
  var n = 0;
  for (final d in days) {
    if (d.rainProbability > maxProb) maxProb = d.rainProbability;
    rainSum += d.rainfallMm;
    n++;
  }
  if (n == 0) return null;
  if (fit == CropRainFit.wet) {
    return maxProb >= _kWetRainProbMin || rainSum >= 8;
  }
  return maxProb < _kDryRainProbMax && rainSum < _kDryRainSumMaxMm;
}

/// Today’s forecast max if present, else current air temp. Null without weather.
double? _airTempC(WeatherSnapshot? weather) {
  if (weather == null) return null;
  if (weather.daily.isEmpty) return weather.temperatureC;
  final todayMax = weather.daily.first.tempMaxC;
  return weather.temperatureC > todayMax ? weather.temperatureC : todayMax;
}

/// Null when the catalog has no range or the reading has no value for that param.
bool? _inRange(double? value, double? min, double? max) {
  if (value == null) return null;
  if (min == null && max == null) return null;
  if (min != null && value < min) return false;
  if (max != null && value > max) return false;
  return true;
}
