/// Loads period weather for Analytics from Open-Meteo using the farm pin.
///
/// Does not read `weather_snapshots` (not persisted yet). Failures throw so
/// the Analytics page can show a visible error without rolling back soil.
library;

import '../../weather/data/farm_location_repository.dart';
import '../../weather/data/open_meteo_weather_service.dart';
import 'period_weather.dart';

/// Farm-pin + Open-Meteo range fetch for the Analytics tab.
class PeriodWeatherRepository {
  PeriodWeatherRepository({
    FarmLocationRepository? location,
    OpenMeteoWeatherService? weather,
  }) : _location = location ?? FarmLocationRepository(),
       _weather = weather ?? OpenMeteoWeatherService();

  final FarmLocationRepository _location;
  final OpenMeteoWeatherService _weather;

  /// Daily weather for [start]..[end] (Manila calendar dates).
  Future<PeriodWeather> fetchRange({
    required DateTime start,
    required DateTime end,
  }) async {
    final pin = await _location.getPrimaryFarmCoordinates();
    if (pin == null) {
      throw StateError(
        'No farm location. Finish onboarding so weather can load.',
      );
    }
    final days = await _weather.fetchDailyRange(
      latitude: pin.latitude,
      longitude: pin.longitude,
      start: start,
      end: end,
    );
    return PeriodWeather(days: days);
  }
}
