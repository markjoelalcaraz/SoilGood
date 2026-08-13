/// Home feature page shown inside the app shell content area (first bottom-nav tab).
///
/// This is the farmer's at-a-glance dashboard after login/onboarding: live soil
/// readings from Supabase, Open-Meteo weather for their farm pin, and one Groq
/// action for today. Not a pushed route — the bottom nav stays mounted.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/ai/groq_chat_client.dart';
import '../../../core/ai/insights_config.dart';
import '../../../core/ai/saved_assessment.dart';
import '../../../core/ai/saved_assessment_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/data/refresh_timeout.dart';
import '../../../shared/widgets/app_refresh_scroll.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../shell/app_shell.dart';
import '../../weather/data/farm_location_repository.dart';
import '../../weather/data/open_meteo_weather_service.dart';
import '../../weather/data/weather_models.dart';
import '../data/soil_reading.dart';
import '../data/soil_readings_repository.dart';
import '../logic/home_ai_client.dart';
import '../logic/home_ai_regen.dart';

/// Home dashboard — live soil, Open-Meteo weather, and one Groq action for today.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _repo = SoilReadingsRepository();
  final _farmRepo = FarmLocationRepository();
  final _weatherService = OpenMeteoWeatherService();
  final _aiRepo = SavedAssessmentRepository();
  final _homeAi = HomeAiClient();

  late final Stream<SoilReading?> _stream;
  SoilReading? _cached;
  Object? _loadError;
  bool _soilFetchDone = false;

  WeatherSnapshot? _weather;
  Object? _weatherError;
  bool _weatherLoading = true;

  SavedAssessment? _assessment;
  Object? _aiError;
  bool _aiLoading = false;

  @override
  void initState() {
    super.initState();
    _stream = _repo.watchLatest();
    _start();
  }

  /// Soil + weather first (cards can paint), then cheap-load / regen Home AI.
  Future<void> _start() async {
    await Future.wait([
      _warmCache(),
      _loadWeather(showSpinner: true),
    ]);
    await _loadHomeAi();
  }

  /// Newer of stream vs pull-fetched cache so pull is not ignored.
  SoilReading? _preferLatest(SoilReading? stream, SoilReading? cached) {
    if (stream == null) return cached;
    if (cached == null) return stream;
    return cached.recordedAt.isAfter(stream.recordedAt) ? cached : stream;
  }

  /// Loads last known reading once for faster first paint.
  Future<void> _warmCache() async {
    try {
      final latest = await withRefreshTimeout(_repo.fetchLatest());
      if (!mounted) return;
      setState(() {
        _cached = latest;
        _loadError = null;
        _soilFetchDone = true;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e;
        _soilFetchDone = true;
      });
    }
  }

  /// Open-Meteo fetch; farm-missing is a visible weather error, not a crash.
  Future<({WeatherSnapshot? weather, Object? error})> _fetchWeather() async {
    final farm = await _farmRepo.getPrimaryFarmCoordinates();
    if (farm == null) {
      return (
        weather: null,
        error:
            'No farm location yet. Finish GPS onboarding to load weather.',
      );
    }
    final weather = await _weatherService.fetch(
      latitude: farm.latitude,
      longitude: farm.longitude,
    );
    return (weather: weather, error: null);
  }

  /// First load may show a section spinner; pull must keep last-known weather.
  Future<void> _loadWeather({required bool showSpinner}) async {
    if (showSpinner && mounted) {
      setState(() => _weatherLoading = true);
    }

    try {
      final result = await withRefreshTimeout(_fetchWeather());
      if (!mounted) return;
      setState(() {
        if (result.error == null) {
          _weather = result.weather;
          _weatherError = null;
        } else {
          _weatherError = result.error;
          if (showSpinner) _weather = result.weather;
        }
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

  /// Pull-to-refresh: refetch soil + weather in parallel. Partial failure OK.
  Future<void> _reloadAll() async {
    Object? soilErr;
    SoilReading? soil;
    Object? weatherErr;
    WeatherSnapshot? weather;

    await Future.wait([
      () async {
        try {
          soil = await withRefreshTimeout(_repo.fetchLatest());
        } on Object catch (e) {
          soilErr = e;
        }
      }(),
      () async {
        try {
          final result = await withRefreshTimeout(_fetchWeather());
          weather = result.weather;
          weatherErr = result.error;
        } on Object catch (e) {
          weatherErr = e;
        }
      }(),
    ]);

    if (!mounted) return;
    setState(() {
      _soilFetchDone = true;
      if (soilErr == null) {
        _cached = soil;
        _loadError = null;
      } else {
        _loadError = soilErr;
      }
      if (weatherErr == null) {
        _weather = weather;
        _weatherError = null;
        _weatherLoading = false;
      } else {
        _weatherError = weatherErr;
        _weatherLoading = false;
      }
    });
    await _loadHomeAi();
  }

  /// Loads saved Home AI; calls Groq only when regen rules say so.
  Future<void> _loadHomeAi() async {
    if (!mounted) return;
    final reading = _cached;
    if (reading == null) {
      if (!mounted) return;
      setState(() {
        _assessment = null;
        _aiError = null;
        _aiLoading = false;
      });
      return;
    }

    setState(() => _aiLoading = true);

    try {
      final farmId = await _farmRepo.getPrimaryFarmId();
      if (farmId == null) {
        throw StateError('No farm found. Finish onboarding first.');
      }
      final insights = await InsightsConfig.load();
      final saved = await withRefreshTimeout(
        _aiRepo.fetchLatest(farmId: farmId, kind: 'home'),
      );

      if (!shouldRegenHomeAi(
        saved: saved,
        soilReadingId: reading.id,
        promptVersion: insights.promptVersion,
      )) {
        if (!mounted) return;
        setState(() {
          _assessment = saved;
          _aiError = null;
          _aiLoading = false;
        });
        return;
      }

      final generated = await _homeAi.generate(
        insights: insights,
        reading: reading,
        weather: _weather,
      );
      final validUntil = DateTime.now().add(
        Duration(hours: insights.homeCacheHours),
      );
      final savedNew = await withRefreshTimeout(
        _aiRepo.save(
          farmId: farmId,
          kind: 'home',
          soilReadingId: reading.id,
          overview: generated.overview,
          soilHealthScore: generated.soilHealthScore,
          modelName: kGroqModel,
          promptVersion: insights.promptVersion,
          validUntil: validUntil,
          recommendations: generated.recommendations,
        ),
      );
      if (!mounted) return;
      setState(() {
        _assessment = savedNew;
        _aiError = null;
        _aiLoading = false;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _aiError = e;
        _aiLoading = false;
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
          final reading = _preferLatest(snapshot.data, _cached);
          final soilError = snapshot.error ?? _loadError;
          final waitingFirstSoil =
              !_soilFetchDone && reading == null && soilError == null;

          return AppRefreshScroll(
            onRefresh: _reloadAll,
            children: [
              if (soilError != null) ...[
                _SourceErrorCard(
                  message: 'Could not load soil readings:\n$soilError',
                ),
                const SizedBox(height: 12),
              ],
              if (waitingFirstSoil)
                const _HomeFirstLoadSkeleton()
              else ...[
                _OverallConditionBanner(reading: reading),
                const SizedBox(height: 24),
                const SectionHeader(
                  title: 'Sensor Findings',
                  icon: Icons.sensors,
                ),
                const SizedBox(height: 12),
                if (reading == null)
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
              ],
              const SizedBox(height: 24),
              const SectionHeader(
                title: 'Forecast',
                icon: Icons.wb_cloudy,
              ),
              const SizedBox(height: 12),
              _ForecastCard(
                weather: _weather,
                loading: _weatherLoading && _weather == null,
                error: _weatherError,
              ),
              const SizedBox(height: 24),
              _AiAdviceCard(
                assessment: _assessment,
                loading: _aiLoading && _assessment == null,
                error: _aiError,
                hasReading: reading != null,
              ),
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

  /// Low/High badge only — skip "Live" so the compact 8-card grid stays readable.
  (String?, StatusChipTone) _rangeChip({
    required double? value,
    double? low,
    double? high,
  }) {
    if (value == null) return (null, StatusChipTone.neutral);
    if (low != null && value < low) return ('Low', StatusChipTone.warn);
    if (high != null && value > high) return ('High', StatusChipTone.warn);
    return (null, StatusChipTone.good);
  }

  @override
  Widget build(BuildContext context) {
    final moisture = reading.moisturePercent;
    final nitrogen = reading.nitrogen;
    final phosphorus = reading.phosphorus;
    final potassium = reading.potassium;
    final salinity = reading.salinity;
    final moistureChip = _rangeChip(value: moisture, low: 30, high: 85);
    final nChip = _rangeChip(value: nitrogen, low: 45);
    final pChip = _rangeChip(value: phosphorus, low: 20);
    final kChip = _rangeChip(value: potassium, low: 80);
    final saltChip = _rangeChip(value: salinity, high: 4);

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 360;
        return GridView.count(
          crossAxisCount: narrow ? 1 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: narrow ? 2.4 : 1.28,
      children: [
        _MetricTile(
          icon: Icons.water_drop_outlined,
          label: 'Moisture',
          value: moisture == null ? '—' : '${moisture.toStringAsFixed(0)}%',
          chip: moistureChip.$1,
          tone: moistureChip.$2,
        ),
        _MetricTile(
          icon: Icons.thermostat,
          label: 'Temperature',
          value: reading.soilTemperatureC?.toStringAsFixed(1) ?? '—',
          unit: '°C',
          iconColor: AppColors.tertiary,
        ),
        _MetricTile(
          icon: Icons.science_outlined,
          label: 'pH Level',
          value: reading.ph?.toStringAsFixed(1) ?? '—',
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
          icon: Icons.waves_outlined,
          label: 'Salinity',
          value: salinity?.toStringAsFixed(1) ?? '—',
          unit: 'ppt',
          chip: saltChip.$1,
          tone: saltChip.$2,
          iconColor: AppColors.secondary,
        ),
        _MetricTile(
          icon: Icons.grass,
          label: 'Nitrogen',
          value: nitrogen?.toStringAsFixed(0) ?? '—',
          unit: 'ppm',
          chip: nChip.$1,
          tone: nChip.$2,
        ),
        _MetricTile(
          icon: Icons.spa_outlined,
          label: 'Phosphorus',
          value: phosphorus?.toStringAsFixed(0) ?? '—',
          unit: 'ppm',
          chip: pChip.$1,
          tone: pChip.$2,
          iconColor: AppColors.primaryContainer,
        ),
        _MetricTile(
          icon: Icons.eco_outlined,
          label: 'Potassium',
          value: potassium?.toStringAsFixed(0) ?? '—',
          unit: 'ppm',
          chip: kChip.$1,
          tone: kChip.$2,
          iconColor: AppColors.tertiary,
        ),
          ],
        );
      },
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
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: constraints.maxWidth,
                maxWidth: constraints.maxWidth,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: iconColor, size: 16),
                      ),
                      const Spacer(),
                      if (chip != null)
                        Flexible(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: StatusChip(label: chip!, tone: tone),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          value,
                          style: GoogleFonts.literata(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (unit != null) ...[
                          const SizedBox(width: 3),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              unit!,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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

    final weatherUi = weather == null
        ? null
        : _weatherBody(context, weather!);

    if (error != null && weatherUi == null) {
      return _SourceErrorCard(message: 'Weather unavailable:\n$error');
    }

    if (weatherUi == null) {
      return const SoftCard(
        child: Text(
          'No weather yet. Save your farm location in onboarding first.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.45),
        ),
      );
    }

    if (error != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SourceErrorCard(message: 'Weather unavailable:\n$error'),
          const SizedBox(height: 12),
          weatherUi,
        ],
      );
    }

    return weatherUi;
  }

  Widget _weatherBody(BuildContext context, WeatherSnapshot weather) {

    final days = weather.daily.take(3).toList();
    final tip = days.length > 1 && days[1].rainProbability >= 40
        ? 'Rain chance ${days[1].rainProbability.toStringAsFixed(0)}% tomorrow — consider pausing irrigation.'
        : 'Now ${weather.temperatureC.toStringAsFixed(0)}°C, ${weather.conditionLabel.toLowerCase()}, humidity ${weather.humidityPercent.toStringAsFixed(0)}%.';

    return SoftCard(
      color: AppColors.surfaceHigh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                weatherCodeIcon(weather.weatherCode),
                color: AppColors.tertiary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${weather.conditionLabel} · ${weather.temperatureC.toStringAsFixed(0)}°C',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.literata(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  'Open-Meteo',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary.withValues(alpha: 0.8),
                  ),
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
  const _AiAdviceCard({
    required this.assessment,
    required this.loading,
    required this.error,
    required this.hasReading,
  });

  final SavedAssessment? assessment;
  final bool loading;
  final Object? error;
  final bool hasReading;

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return _SourceErrorCard(message: 'Today’s AI tip unavailable:\n$error');
    }
    if (loading) {
      return const SoftCard(
        color: AppColors.surfaceMuted,
        child: SizedBox(height: 120),
      );
    }
    if (!hasReading) {
      return const SoftCard(
        color: AppColors.secondaryContainer,
        padding: EdgeInsets.all(22),
        child: Text(
          'AI needs a soil reading before it can advise watering today.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.5),
        ),
      );
    }
    if (assessment == null) {
      return const SizedBox.shrink();
    }

    final rec = assessment!.recommendations.isEmpty
        ? null
        : assessment!.recommendations.first;

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
              const Expanded(
                child: Text(
                  'AI RECOMMENDATION',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: AppColors.secondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            rec?.title ?? 'Today',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.literata(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              height: 1.25,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            rec?.recommendedAction.isNotEmpty == true
                ? rec!.recommendedAction
                : assessment!.overview,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 15,
              height: 1.55,
            ),
          ),
          if (rec != null &&
              rec.description.isNotEmpty &&
              rec.recommendedAction.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              rec.description,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Visible per-source failure that does not replace the rest of the page.
class _SourceErrorCard extends StatelessWidget {
  const _SourceErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      color: AppColors.errorContainer,
      child: Text(
        message,
        style: const TextStyle(color: Color(0xFF690005), height: 1.5),
      ),
    );
  }
}

/// First-open structure only — never used during pull-to-refresh.
class _HomeFirstLoadSkeleton extends StatelessWidget {
  const _HomeFirstLoadSkeleton();

  @override
  Widget build(BuildContext context) {
    final narrow = isNarrowPhone(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SoftCard(
          color: AppColors.surfaceMuted,
          child: SizedBox(height: narrow ? 160 : 140),
        ),
        const SizedBox(height: 24),
        const SectionHeader(title: 'Sensor Findings', icon: Icons.sensors),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: narrow ? 1 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: narrow ? 2.4 : 1.42,
          children: List.generate(
            4,
            (_) => const SoftCard(
              color: AppColors.surfaceMuted,
              child: SizedBox(height: 48),
            ),
          ),
        ),
      ],
    );
  }
}
