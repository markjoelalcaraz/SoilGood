/// Home feature page shown inside the app shell content area (first bottom-nav tab).
///
/// This is the farmer's at-a-glance dashboard after login/onboarding: live soil
/// readings from Supabase plus Open-Meteo weather for their farm pin. Not a pushed
/// route — the bottom nav stays mounted while this page is visible.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../shell/app_shell.dart';
import '../../weather/data/farm_location_repository.dart';
import '../../weather/data/open_meteo_weather_service.dart';
import '../../weather/data/weather_models.dart';
import '../data/soil_reading.dart';
import '../data/soil_readings_repository.dart';

/// Home dashboard — live soil readings + Open-Meteo weather when farm pin exists.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _repo = SoilReadingsRepository();
  final _farmRepo = FarmLocationRepository();
  final _weatherService = OpenMeteoWeatherService();

  late final Stream<SoilReading?> _stream;
  SoilReading? _cached;
  Object? _loadError;

  WeatherSnapshot? _weather;
  Object? _weatherError;
  bool _weatherLoading = true;

  @override
  void initState() {
    super.initState();
    _stream = _repo.watchLatest();
    _warmCache();
    _loadWeather();
  }

  /// Loads last known reading once for faster first paint.
  Future<void> _warmCache() async {
    try {
      final latest = await _repo.fetchLatest();
      if (mounted) setState(() => _cached = latest);
    } on Object catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  /// Loads Open-Meteo weather using the farm's saved lat/long.
  Future<void> _loadWeather() async {
    setState(() {
      _weatherLoading = true;
      _weatherError = null;
    });

    try {
      final farm = await _farmRepo.getPrimaryFarmCoordinates();
      if (farm == null) {
        setState(() {
          _weather = null;
          _weatherLoading = false;
          _weatherError =
              'No farm location yet. Finish GPS onboarding to load weather.';
        });
        return;
      }

      final weather = await _weatherService.fetch(
        latitude: farm.latitude,
        longitude: farm.longitude,
      );
      if (!mounted) return;
      setState(() {
        _weather = weather;
        _weatherLoading = false;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _weatherError = e;
        _weatherLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const SoilGoodTopBar(title: 'SoilGood'),
      body: StreamBuilder<SoilReading?>(
        stream: _stream,
        initialData: _cached,
        builder: (context, snapshot) {
          if (snapshot.hasError || _loadError != null) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SoftCard(
                  color: AppColors.errorContainer,
                  child: Text(
                    'Could not load soil readings:\n${snapshot.error ?? _loadError}',
                    style: const TextStyle(
                      color: Color(0xFF690005),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            );
          }

          final reading = snapshot.data ?? _cached;
          final waiting =
              snapshot.connectionState == ConnectionState.waiting &&
              reading == null;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _OverallConditionBanner(reading: reading),
              const SizedBox(height: 24),
              const SectionHeader(
                title: 'Sensor Findings',
                icon: Icons.sensors,
              ),
              const SizedBox(height: 12),
              if (waiting)
                const SoftCard(
                  child: SizedBox(
                    height: 120,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              else if (reading == null)
                const SoftCard(
                  child: Text(
                    'No soil readings yet.\nLink a device in onboarding and wait for the ESP32 (or insert a test row in Supabase).',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                )
              else
                _SensorGrid(reading: reading),
              const SizedBox(height: 24),
              SectionHeader(
                title: 'Forecast',
                icon: Icons.wb_cloudy,
                trailing: IconButton(
                  tooltip: 'Refresh weather',
                  onPressed: _weatherLoading ? null : _loadWeather,
                  icon: const Icon(Icons.refresh, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 12),
              _ForecastCard(
                weather: _weather,
                loading: _weatherLoading,
                error: _weatherError,
              ),
              const SizedBox(height: 24),
              const _AiAdviceCard(),
            ],
          );
        },
      ),
    );
  }
}

class _OverallConditionBanner extends StatelessWidget {
  const _OverallConditionBanner({required this.reading});

  final SoilReading? reading;

  String get _statusLabel {
    if (reading == null) return 'WAITING';
    if (reading!.validationStatus == 'error') return 'SENSOR ERROR';
    if (reading!.validationStatus == 'warning') return 'CHECK SENSORS';
    final moisture = reading!.moisturePercent;
    if (moisture != null && moisture < 30) return 'DRY';
    if (moisture != null && moisture > 85) return 'WET';
    return 'OPTIMAL';
  }

  String get _insight {
    if (reading == null) {
      return 'Connect a device to see live soil insights here.';
    }
    final m = reading!.moisturePercent?.toStringAsFixed(0) ?? '—';
    final n = reading!.nitrogen?.toStringAsFixed(0) ?? '—';
    return 'Latest moisture $m%. Nitrogen $n ppm. Updated ${_formatTime(reading!.recordedAt)}.';
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F2E3230),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -30,
            child: Icon(
              Icons.eco,
              size: 140,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'YOUR FARM OVERVIEW',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Overall Soil Condition',
                style: GoogleFonts.literata(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              Text(
                _statusLabel,
                style: GoogleFonts.literata(
                  color: AppColors.background,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.28),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'QUICK INSIGHT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _insight,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SensorGrid extends StatelessWidget {
  const _SensorGrid({required this.reading});

  final SoilReading reading;

  @override
  Widget build(BuildContext context) {
    final moisture = reading.moisturePercent;
    final nitrogen = reading.nitrogen;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.05,
      children: [
        _MetricTile(
          icon: Icons.water_drop_outlined,
          label: 'Moisture',
          value: moisture == null ? '—' : '${moisture.toStringAsFixed(0)}%',
          chip: moisture == null
              ? null
              : (moisture < 30
                    ? 'Low'
                    : moisture > 85
                    ? 'High'
                    : 'OK'),
          tone: moisture != null && moisture < 30
              ? StatusChipTone.warn
              : StatusChipTone.good,
        ),
        _MetricTile(
          icon: Icons.science_outlined,
          label: 'pH Level',
          value: reading.ph?.toStringAsFixed(1) ?? '—',
          chip: 'Live',
          tone: StatusChipTone.neutral,
          iconColor: AppColors.tertiary,
        ),
        _MetricTile(
          icon: Icons.bolt_outlined,
          label: 'EC',
          value: reading.ec?.toStringAsFixed(1) ?? '—',
          unit: 'dS/m',
          iconColor: AppColors.secondary,
        ),
        _MetricTile(
          icon: Icons.grass,
          label: 'Nitrogen',
          value: nitrogen?.toStringAsFixed(0) ?? '—',
          unit: 'ppm',
          chip: nitrogen != null && nitrogen < 45 ? 'Low' : 'Live',
          tone: nitrogen != null && nitrogen < 45
              ? StatusChipTone.warn
              : StatusChipTone.good,
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    this.unit,
    this.chip,
    this.tone = StatusChipTone.neutral,
    this.iconColor = AppColors.primary,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? unit;
  final String? chip;
  final StatusChipTone tone;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const Spacer(),
              if (chip != null) StatusChip(label: chip!, tone: tone),
            ],
          ),
          const Spacer(),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: GoogleFonts.literata(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    unit!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ForecastCard extends StatelessWidget {
  const _ForecastCard({
    required this.weather,
    required this.loading,
    required this.error,
  });

  final WeatherSnapshot? weather;
  final bool loading;
  final Object? error;

  String _dayLabel(DateTime date, int index) {
    if (index == 0) return 'Today';
    if (index == 1) return 'Tomorrow';
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[date.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SoftCard(
        child: SizedBox(
          height: 140,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (error != null) {
      return SoftCard(
        color: AppColors.errorContainer,
        child: Text(
          'Weather unavailable:\n$error',
          style: const TextStyle(color: Color(0xFF690005), height: 1.45),
        ),
      );
    }

    if (weather == null) {
      return const SoftCard(
        child: Text(
          'No weather yet. Save your farm location in onboarding first.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.45),
        ),
      );
    }

    final days = weather!.daily.take(3).toList();
    final tip = days.length > 1 && days[1].rainProbability >= 40
        ? 'Rain chance ${days[1].rainProbability.toStringAsFixed(0)}% tomorrow — consider pausing irrigation.'
        : 'Now ${weather!.temperatureC.toStringAsFixed(0)}°C, ${weather!.conditionLabel.toLowerCase()}, humidity ${weather!.humidityPercent.toStringAsFixed(0)}%.';

    return SoftCard(
      color: AppColors.surfaceHigh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                weatherCodeIcon(weather!.weatherCode),
                color: AppColors.tertiary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${weather!.conditionLabel} · ${weather!.temperatureC.toStringAsFixed(0)}°C',
                  style: GoogleFonts.literata(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
              Text(
                'Open-Meteo',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 130,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: days.length,
              itemBuilder: (context, index) {
                final day = days[index];
                return _DayForecast(
                  label: _dayLabel(day.date, index),
                  icon: weatherCodeIcon(day.weatherCode),
                  high: '${day.tempMaxC.round()}°',
                  low: '${day.tempMinC.round()}°',
                  active: index == 0,
                );
              },
            ),
          ),
          const Divider(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline,
                size: 18,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tip,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayForecast extends StatelessWidget {
  const _DayForecast({
    required this.label,
    required this.icon,
    required this.high,
    required this.low,
    this.active = false,
  });

  final String label;
  final IconData icon;
  final String high;
  final String low;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: active
            ? AppColors.surface
            : AppColors.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: active ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Icon(icon, color: active ? AppColors.tertiary : AppColors.primary),
          const SizedBox(height: 8),
          Text(
            high,
            style: GoogleFonts.literata(
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          Text(
            low,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _AiAdviceCard extends StatelessWidget {
  const _AiAdviceCard();

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      color: AppColors.secondaryContainer,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: AppColors.secondary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.psychology,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'AI RECOMMENDATION',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Sample advice until the AI module is wired.',
            style: GoogleFonts.literata(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              height: 1.25,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Live soil values now drive the sensor cards above. '
            'Irrigation and crop recommendations will use those readings next.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 15,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}
