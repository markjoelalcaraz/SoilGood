/// Home feature page shown inside the app shell content area (first bottom-nav tab).
///
/// This is the farmer's at-a-glance dashboard after login/onboarding: live soil
/// readings from Supabase, Open-Meteo weather for their farm pin, and three Groq
/// tips for today (Condition, Water today, Nutrients). Realtime soil updates
/// also recheck Home AI (fingerprint gate — Groq only when the story changed).
/// Not a pushed route — the bottom nav stays mounted.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/ai/crop_band_classify.dart';
import '../../../core/ai/groq_chat_client.dart';
import '../../../core/ai/insights_config.dart';
import '../../../core/ai/saved_assessment.dart';
import '../../../core/ai/saved_assessment_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/data/refresh_timeout.dart';
import '../../../shared/widgets/app_refresh_scroll.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../crops/data/crops_repository.dart';
import '../../crops/logic/crop_timeline.dart';
import '../../shell/app_shell.dart';
import '../../weather/data/farm_location_repository.dart';
import '../../weather/data/open_meteo_weather_service.dart';
import '../../weather/data/weather_models.dart';
import '../data/soil_reading.dart';
import '../data/soil_readings_repository.dart';
import '../logic/home_ai_client.dart';
import '../logic/home_ai_regen.dart';
import '../logic/home_ai_story.dart';

/// Home dashboard — live soil, weather, and three Groq tips for today.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _repo = SoilReadingsRepository();
  final _farmRepo = FarmLocationRepository();
  final _cropsRepo = CropsRepository();
  final _weatherService = OpenMeteoWeatherService();
  final _aiRepo = SavedAssessmentRepository();
  final _homeAi = HomeAiClient();

  StreamSubscription<SoilReading?>? _soilSub;
  SoilReading? _streamReading;
  SoilReading? _cached;
  Object? _loadError;
  bool _soilFetchDone = false;

  WeatherSnapshot? _weather;
  Object? _weatherError;
  bool _weatherLoading = true;

  SavedAssessment? _assessment;
  Object? _aiError;
  bool _aiLoading = false;
  bool _hasActiveCrop = false;

  /// Last soil row id that already triggered an AI recheck (Realtime path).
  String? _lastRealtimeAiSoilId;

  /// Coalesce overlapping open/pull/Realtime AI loads into one follow-up.
  bool _aiBusy = false;
  bool _aiQueued = false;

  @override
  void initState() {
    super.initState();
    _soilSub = _repo.watchLatest().listen(
      _onSoilStreamEvent,
      onError: (Object e) {
        if (!mounted) return;
        setState(() => _loadError = e);
      },
    );
    _start();
  }

  @override
  void dispose() {
    unawaited(_soilSub?.cancel() ?? Future.value());
    super.dispose();
  }

  /// Soil + weather first (cards can paint), then cheap-load / regen Home AI.
  Future<void> _start() async {
    await Future.wait([
      _warmCache(),
      _loadWeather(showSpinner: true),
    ]);
    await _loadHomeAi();
  }

  /// Realtime soil: update cards, then recheck AI only when the reading id is new.
  void _onSoilStreamEvent(SoilReading? reading) {
    if (!mounted) return;

    setState(() {
      _streamReading = reading;
      if (reading != null) {
        _cached = _preferLatest(reading, _cached);
        _soilFetchDone = true;
        _loadError = null;
      }
    });

    final latest = _preferLatest(reading, _cached);
    if (latest == null) return;
    if (latest.id == _lastRealtimeAiSoilId) return;

    _lastRealtimeAiSoilId = latest.id;
    unawaited(_loadHomeAi());
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

  /// Loads saved Home AI; calls Groq only when the story fingerprint says so.
  ///
  /// Overlapping open / pull / Realtime calls coalesce so at most one follow-up
  /// run happens after the current one finishes.
  Future<void> _loadHomeAi() async {
    if (!mounted) return;
    if (_aiBusy) {
      _aiQueued = true;
      return;
    }
    _aiBusy = true;
    try {
      do {
        _aiQueued = false;
        await _loadHomeAiOnce();
      } while (_aiQueued && mounted);
    } finally {
      _aiBusy = false;
    }
  }

  /// One Home AI cheap-load / regen pass against the current `_cached` reading.
  Future<void> _loadHomeAiOnce() async {
    if (!mounted) return;
    final reading = _preferLatest(_streamReading, _cached);
    if (reading == null) {
      if (!mounted) return;
      setState(() {
        _assessment = null;
        _aiError = null;
        _aiLoading = false;
        _hasActiveCrop = false;
      });
      return;
    }

    _lastRealtimeAiSoilId = reading.id;
    // Soft load: keep last tips on screen when we already have an assessment.
    setState(() => _aiLoading = true);

    try {
      final farmId = await _farmRepo.getPrimaryFarmId();
      if (farmId == null) {
        throw StateError('No farm found. Finish onboarding first.');
      }
      final insights = await InsightsConfig.load();
      final planting = await withRefreshTimeout(
        _cropsRepo.fetchActivePlanting(farmId),
      );
      final timeline = planting == null ? null : timelineFor(planting);
      final hasCrop = planting != null;
      final cropName = planting?.crop.name;
      final phaseId = timeline?.current.id ?? (hasCrop ? 'unknown' : null);
      final phaseLabel = timeline?.current.label ?? (hasCrop ? 'growing' : null);
      final cropRanges = planting == null
          ? null
          : CropBandRanges.fromCrop(planting.crop, phaseId: phaseId);

      final fingerprint = buildHomeStoryFingerprint(
        insights: insights,
        reading: reading,
        weather: _weather,
        cropName: hasCrop ? cropName : null,
        phaseId: hasCrop ? phaseId : null,
        cropRanges: cropRanges,
      );

      final saved = await withRefreshTimeout(
        _aiRepo.fetchLatest(farmId: farmId, kind: 'home'),
      );

      if (!shouldRegenHomeAi(
        saved: saved,
        promptVersion: insights.promptVersion,
        currentFingerprint: fingerprint,
      )) {
        if (!mounted) return;
        setState(() {
          _assessment = saved;
          _hasActiveCrop = hasCrop;
          _aiError = null;
          _aiLoading = false;
        });
        return;
      }

      final generated = await _homeAi.generate(
        insights: insights,
        reading: reading,
        weather: _weather,
        cropName: hasCrop ? cropName : null,
        phaseId: hasCrop ? phaseId : null,
        phaseLabel: hasCrop ? phaseLabel : null,
        cropRanges: cropRanges,
      );
      final validUntil = DateTime.now().add(
        Duration(hours: insights.homeCacheHours),
      );
      final stampedOverview = encodeHomeOverviewWithFingerprint(
        fingerprint: fingerprint,
        overview: generated.overview,
      );
      final savedNew = await withRefreshTimeout(
        _aiRepo.save(
          farmId: farmId,
          kind: 'home',
          plantingId: hasCrop ? planting.id : null,
          soilReadingId: reading.id,
          overview: stampedOverview,
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
        _hasActiveCrop = hasCrop;
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
    final reading = _preferLatest(_streamReading, _cached);
    final soilError = _loadError;
    final waitingFirstSoil =
        !_soilFetchDone && reading == null && soilError == null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const SoilGoodTopBar(title: 'SoilGood'),
      body: AppRefreshScroll(
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
          _HomeAiTipsSection(
            assessment: _assessment,
            loading: _aiLoading && _assessment == null,
            error: _aiError,
            hasReading: reading != null,
            hasActiveCrop: _hasActiveCrop,
          ),
        ],
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

class _HomeAiTipsSection extends StatelessWidget {
  const _HomeAiTipsSection({
    required this.assessment,
    required this.loading,
    required this.error,
    required this.hasReading,
    required this.hasActiveCrop,
  });

  final SavedAssessment? assessment;
  final bool loading;
  final Object? error;
  final bool hasReading;
  final bool hasActiveCrop;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          title: 'Tips for today',
          icon: Icons.psychology_outlined,
        ),
        const SizedBox(height: 12),
        if (error != null)
          _SourceErrorCard(message: 'Today’s tips unavailable:\n$error')
        else if (loading)
          const _HomeAiTipsSkeleton()
        else if (!hasReading)
          const SoftCard(
            color: AppColors.secondaryContainer,
            padding: EdgeInsets.all(22),
            child: Text(
              'Tips need a soil reading before they can help with watering and plant food today.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.5),
            ),
          )
        else if (assessment == null)
          const SizedBox.shrink()
        else ...[
          _HomeTipCard(
            slotLabel: 'Condition',
            icon: Icons.grass,
            rec: _recOf(assessment!, 'soil_management'),
          ),
          const SizedBox(height: 10),
          _HomeTipCard(
            slotLabel: 'Water today',
            icon: Icons.water_drop,
            rec: _recOf(assessment!, 'irrigation'),
          ),
          const SizedBox(height: 10),
          if (hasActiveCrop)
            _HomeTipCard(
              slotLabel: 'Nutrients',
              icon: Icons.science,
              rec: _recOf(assessment!, 'nutrient'),
            )
          else
            const _NutrientsCropCtaCard(),
        ],
      ],
    );
  }

  /// Prefer exact type; fall back to list order for older 1-tip rows.
  static AiRecommendation? _recOf(SavedAssessment a, String type) {
    for (final r in a.recommendations) {
      if (r.type == type) return r;
    }
    if (type == 'irrigation' && a.recommendations.length == 1) {
      return a.recommendations.first;
    }
    return null;
  }
}

/// One of the three Home tip slots.
class _HomeTipCard extends StatelessWidget {
  const _HomeTipCard({
    required this.slotLabel,
    required this.icon,
    required this.rec,
  });

  final String slotLabel;
  final IconData icon;
  final AiRecommendation? rec;

  @override
  Widget build(BuildContext context) {
    final high = rec?.priority == 'high';
    return SoftCard(
      color: high
          ? AppColors.secondaryContainer
          : AppColors.surface,
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        slotLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: AppColors.secondary,
                        ),
                      ),
                    ),
                    if (rec != null && rec!.recommendedAction.isNotEmpty)
                      StatusChip(
                        label: rec!.recommendedAction,
                        tone: _actionTone(rec!.recommendedAction),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  rec?.title ?? 'Pull to refresh',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.literata(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  rec?.description.isNotEmpty == true
                      ? rec!.description
                      : 'No tip yet for this card. Pull the page to refresh.',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static StatusChipTone _actionTone(String action) {
    final lower = action.toLowerCase();
    if (lower.contains('wait') || lower.contains('hold') || lower.contains('okay') || lower.contains('fine') || lower.contains('no worry')) {
      return StatusChipTone.good;
    }
    if (lower.contains('water') || lower.contains('irrigate') || lower.contains('fertilizer') || lower.contains('add')) {
      return StatusChipTone.warn;
    }
    if (lower.contains('check') || lower.contains('sensor')) {
      return StatusChipTone.neutral;
    }
    return StatusChipTone.neutral;
  }
}

/// Nutrients slot when the farmer has not selected an active crop.
class _NutrientsCropCtaCard extends StatelessWidget {
  const _NutrientsCropCtaCard();

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      color: AppColors.surfaceMuted,
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.science, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nutrients',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tell us your crop',
                  style: GoogleFonts.literata(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Add what you planted so fertilizer tips can match your crop and growing stage. Without that, we should not guess fertilizer for you.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () {
                      ShellScope.maybeOf(context)?.selectTab(2);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      minimumSize: const Size(48, 48),
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Open Crops',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// First-open placeholders for the three tip cards.
class _HomeAiTipsSkeleton extends StatelessWidget {
  const _HomeAiTipsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (i) => Padding(
          padding: EdgeInsets.only(bottom: i == 2 ? 0 : 10),
          child: const SoftCard(
            color: AppColors.surfaceMuted,
            child: SizedBox(height: 110),
          ),
        ),
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
