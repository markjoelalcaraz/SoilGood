/// Home feature page shown inside the app shell content area (first bottom-nav tab).
///
/// This is the farmer's at-a-glance dashboard after login/onboarding: live soil
/// readings from Supabase, Open-Meteo weather for their farm pin, and Groq
/// tips for today (Condition, Water today, Nutrients, and Crop care when planted),
/// then quick stats and the sensor numbers. The farm picture sits on top.
/// The farm can grow several crops: the header opens a crop picker, and every
/// stat on Home follows the selected crop's sensors ([SelectedCrop]). A crop
/// with no sensor shows only "Add sensor" — no numbers, no tips.
/// Realtime soil updates also recheck Home AI (fingerprint gate — Groq only when
/// the story changed). Not a pushed route — the bottom nav stays mounted.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/ai/crop_band_classify.dart';
import '../../../core/ai/groq_chat_client.dart';
import '../../../core/ai/insights_config.dart';
import '../../../core/ai/saved_assessment.dart';
import '../../../core/ai/saved_assessment_repository.dart';
import '../../../core/live/farm_live_hub.dart';
import '../../../core/live/live_page.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/data/refresh_timeout.dart';
import '../../../shared/navigation/app_page_routes.dart';
import '../../../shared/widgets/app_refresh_scroll.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../crops/data/planting.dart';
import '../../crops/data/crops_repository.dart';
import '../../crops/logic/crop_timeline.dart';
import '../../crops/logic/planting_band_ranges.dart';
import '../../crops/logic/selected_crop.dart';
import '../../crops/presentation/add_crop/add_crop_wizard_page.dart';
import '../../farm/data/farm_sensor.dart';
import '../../farm/data/plot_sensors_repository.dart';
import '../../farm/logic/crop_illustration.dart';
import '../../farm/logic/sensor_area_copy.dart';
import '../../farm/presentation/add_sensor_page.dart';
import '../../notifications/logic/notification_scope.dart';
import '../../notifications/presentation/notifications_page.dart';
import '../../shell/app_shell.dart';
import '../../weather/data/farm_location_repository.dart';
import '../../weather/data/open_meteo_weather_service.dart';
import '../../weather/data/weather_models.dart';
import '../data/soil_reading.dart';
import '../data/soil_readings_repository.dart';
import '../logic/home_ai_client.dart';
import '../logic/home_ai_regen.dart';
import '../logic/home_ai_story.dart';
import '../logic/live_soil_truth.dart';
import '../logic/quick_soil_insight.dart';

/// Home dashboard — live soil, weather, and Groq tips for today.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with LivePage {
  final _repo = SoilReadingsRepository();
  final _sensorsRepo = PlotSensorsRepository();
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

  /// Every active crop on the farm (picker rows).
  List<Planting> _plantings = [];

  /// Selected crop; Home stats follow its sensors. Null = nothing planted.
  Planting? _planting;
  Object? _cropsError;
  String? _farmName;
  Object? _farmNameError;
  List<FarmSensor> _sensors = [];
  Object? _sensorError;

  /// Last soil row id that already triggered an AI recheck (Realtime path).
  String? _lastRealtimeAiSoilId;

  /// Coalesce overlapping open/pull/Realtime AI loads into one follow-up.
  bool _aiBusy = false;
  bool _aiQueued = false;

  @override
  Set<LiveSource> get liveSources => const {
    LiveSource.plantings,
    LiveSource.devices,
    LiveSource.farms,
    LiveSource.assessments,
  };

  /// Crop, sensor list, farm name, or saved tips changed. Soil has its own stream.
  @override
  Future<void> onLive(Set<LiveSource> changed) async {
    if (changed.contains(LiveSource.farms)) await _loadFarmName();
    if (changed.contains(LiveSource.devices)) await _loadSensors();
    if (changed.contains(LiveSource.plantings)) await _loadCrops();
    if (changed.contains(LiveSource.plantings) ||
        changed.contains(LiveSource.assessments) ||
        changed.contains(LiveSource.farms)) {
      await _loadHomeAi();
    }
  }

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
    SelectedCrop.instance.plantingId.addListener(_onSelectedCropChanged);
    _start();
    unawaited(_loadFarmName());
  }

  @override
  void dispose() {
    SelectedCrop.instance.plantingId.removeListener(_onSelectedCropChanged);
    unawaited(_soilSub?.cancel() ?? Future.value());
    super.dispose();
  }

  /// Picker here or a chip on Farm switched crops. Swap stats, then recheck tips.
  void _onSelectedCropChanged() {
    if (!mounted) return;
    final next = SelectedCrop.instance.resolve(_plantings);
    if (next?.id == _planting?.id) return;
    setState(() {
      _planting = next;
      _hasActiveCrop = next != null;
      _assessment = null;
      _aiError = null;
    });
    unawaited(_loadHomeAi());
  }

  /// Every active crop, then the saved selection (or the oldest crop).
  Future<void> _loadCrops() async {
    try {
      final farmId = await withRefreshTimeout(_farmRepo.getPrimaryFarmId());
      if (farmId == null || !mounted) return;
      final plantings = await withRefreshTimeout(
        _cropsRepo.fetchActivePlantings(farmId),
      );
      await SelectedCrop.instance.restore();
      if (!mounted) return;
      final selected = SelectedCrop.instance.resolve(plantings);
      final switched = selected?.id != _planting?.id;
      setState(() {
        _plantings = plantings;
        _planting = selected;
        _hasActiveCrop = selected != null;
        _cropsError = null;
        if (switched) _assessment = null;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _cropsError = e);
    }
  }

  /// Sensors placed on the selected crop's plot.
  List<FarmSensor> _cropSensors() {
    final planting = _planting;
    if (planting == null) return const [];
    return [
      for (final s in _sensors)
        if (s.plantingId == planting.id) s,
    ];
  }

  /// Reading Home shows: newest from the selected crop's sensors.
  ///
  /// With nothing planted, falls back to the newest reading on the farm.
  SoilReading? _displayReading() {
    if (_planting == null) return _preferLatest(_streamReading, _cached);
    SoilReading? newest;
    for (final s in _cropSensors()) {
      final r = s.latest;
      if (r == null) continue;
      if (newest == null || r.recordedAt.isAfter(newest.recordedAt)) {
        newest = r;
      }
    }
    return newest;
  }

  /// Opens the Add a crop wizard. The new crop becomes selected when planted.
  Future<void> _openAddCrop() async {
    final planted = await Navigator.of(context).push<bool>(
      AppPageRoutes.slideFromRight(const AddCropWizardPage()),
    );
    if (planted == true) await _loadCrops();
  }

  /// Claims a new kit onto the selected crop.
  Future<void> _openAddSensor() async {
    final planting = _planting;
    if (planting == null) return;
    final added = await Navigator.of(context).push<bool>(
      AppPageRoutes.slideFromRight(
        AddSensorPage(plantingId: planting.id, cropName: planting.crop.name),
      ),
    );
    if (added == true) {
      await _loadSensors();
      await _loadHomeAi();
    }
  }

  /// Moves an already-claimed kit with no plot onto the selected crop.
  Future<void> _placeSensor(FarmSensor sensor) async {
    final planting = _planting;
    if (planting == null) return;
    try {
      await _sensorsRepo.placeOnPlot(
        deviceId: sensor.id,
        plantingId: planting.id,
      );
      await _loadSensors();
      await _loadHomeAi();
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _sensorError = e is StateError ? e.message : e);
    }
  }

  /// Display name for the home greeting. A missing name stays blank, not a fake farm.
  Future<void> _loadFarmName() async {
    try {
      final name = await withRefreshTimeout(_farmRepo.getPrimaryFarmName());
      if (!mounted) return;
      setState(() {
        _farmName = name;
        _farmNameError = null;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _farmNameError = e);
    }
  }

  /// Soil, weather, crops, and sensors first (cards can paint), then Home AI.
  Future<void> _start() async {
    await Future.wait([
      _warmCache(),
      _loadWeather(showSpinner: true),
      _loadCrops(),
      _loadSensors(),
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
    if (latest.id == _lastRealtimeAiSoilId) {
      unawaited(_loadSensors());
      return;
    }

    _lastRealtimeAiSoilId = latest.id;
    unawaited(_loadWeather(showSpinner: false));
    // Per-crop readings come from the sensor list, so refresh it before tips.
    unawaited(() async {
      await _loadSensors();
      await _loadHomeAi();
    }());
  }

  /// Kits on this farm, each with its latest reading, for the area lines.
  Future<void> _loadSensors() async {
    try {
      final farmId = await withRefreshTimeout(_farmRepo.getPrimaryFarmId());
      if (farmId == null || !mounted) return;
      final sensors = await withRefreshTimeout(
        _sensorsRepo.listForFarm(farmId),
      );
      if (!mounted) return;
      setState(() {
        _sensors = sensors;
        _sensorError = null;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _sensorError = e);
    }
  }

  /// Newer of stream vs pull-fetched cache so pull is not ignored.
  SoilReading? _preferLatest(SoilReading? stream, SoilReading? cached) {
    return preferLatest(stream, cached);
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
    await Future.wait([_loadCrops(), _loadSensors(), _loadFarmName()]);
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

  /// One Home AI cheap-load / regen pass for the selected crop's reading.
  ///
  /// A crop with no sensor reading gets no tips (Home shows Add sensor).
  Future<void> _loadHomeAiOnce() async {
    if (!mounted) return;
    final planting = _planting;
    final reading = _displayReading();
    if (reading == null) {
      if (!mounted) return;
      setState(() {
        _assessment = null;
        _aiError = null;
        _aiLoading = false;
        _hasActiveCrop = planting != null;
      });
      return;
    }

    // Soft load: keep last tips on screen when we already have an assessment.
    setState(() => _aiLoading = true);

    try {
      final farmId = await _farmRepo.getPrimaryFarmId();
      if (farmId == null) {
        throw StateError('No farm found. Finish onboarding first.');
      }
      final insights = await InsightsConfig.load();
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
        _aiRepo.fetchLatest(
          farmId: farmId,
          kind: 'home',
          plantingId: planting?.id,
        ),
      );

      // The farmer switched crops while this pass was running.
      if (!mounted || _planting?.id != planting?.id) return;

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
      if (!mounted || _planting?.id != planting?.id) return;
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

  /// Sticker code for the reading currently on screen, when we know the kit.
  String? _codeForReading(SoilReading? reading) {
    if (reading == null) return null;
    for (final sensor in _sensors) {
      if (sensor.latest?.id == reading.id || sensor.id == reading.deviceId) {
        return sensor.claimCode;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final farmReading = _preferLatest(_streamReading, _cached);
    final reading = _displayReading();
    final soilError = _loadError;
    final planting = _planting;
    final cropSensors = _cropSensors();
    // Selected crop has no kit on its plot: show Add sensor, never farm numbers.
    final noSensor = planting != null && cropSensors.isEmpty;
    final watched = planting == null ? _sensors : cropSensors;
    CropBandRanges? rangesOf(FarmSensor s) => sensorBandRanges(s, _plantings);
    final attention = [
      for (final sensor in watched)
        if (sensor.latest != null &&
            sensorAreaFlag(sensor.latest!, crop: rangesOf(sensor)) !=
                SensorAreaFlag.ok)
          sensor,
    ];
    final shown = attention.isNotEmpty ? attention.first.latest : reading;
    // Judge the shown reading by the crop on its plot (selected crop if none flagged).
    final shownRanges = attention.isNotEmpty
        ? rangesOf(attention.first)
        : planting == null
        ? null
        : plantingBandRanges(planting);
    final shownCode = attention.isNotEmpty
        ? attention.first.claimCode
        : _codeForReading(reading);
    final waitingFirstSoil =
        !_soilFetchDone && farmReading == null && soilError == null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          AppRefreshScroll(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
        onRefresh: _reloadAll,
        children: [
          _HomeStage(
            hero: _HomeHero(
              farmName: _farmName,
              nameError: _farmNameError,
              plantings: _plantings,
              selected: planting,
              sensors: _sensors,
              cropsError: _cropsError,
              onSelectCrop: (p) => SelectedCrop.instance.select(p.id),
              onAddCrop: _openAddCrop,
            ),
            focus: waitingFirstSoil || noSensor
                ? null
                : _HomeFocusRow(
                    reading: shown,
                    weather: _weather,
                    crop: shownRanges,
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
          if (attention.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final sensor in attention) ...[
              SoftCard(
                color: AppColors.errorContainer,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sensorAreaHeadline(
                        claimCode: sensor.claimCode,
                        flag: sensorAreaFlag(
                          sensor.latest!,
                          crop: rangesOf(sensor),
                        ),
                        cropName: sensor.cropName,
                      ),
                      style: const TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sensorAreaDetail(
                        sensor.latest!,
                        sensorAreaFlag(sensor.latest!, crop: rangesOf(sensor)),
                      ),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
          const SizedBox(height: 16),
          if (soilError != null) ...[
            _SourceErrorCard(
              message: 'Could not load soil readings:\n$soilError',
            ),
            const SizedBox(height: 12),
          ],
          if (_sensorError != null) ...[
            _SourceErrorCard(
              message: 'Could not load sensors:\n$_sensorError',
            ),
            const SizedBox(height: 12),
          ],
          if (waitingFirstSoil)
            const _HomeFirstLoadSkeleton()
          else if (noSensor)
            _NoSensorCard(
              planting: planting,
              unplaced: [
                for (final s in _sensors)
                  if (!s.onActivePlot) s,
              ],
              onAdd: _openAddSensor,
              onPlace: _placeSensor,
            )
          else ...[
            if (shown != null) ...[
              const SizedBox(height: 10),
              Text(
                quickSoilInsight(shown, crop: shownRanges),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.45,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 20),
            _HomeAiTipsSection(
              assessment: _assessment,
              loading: _aiLoading && _assessment == null,
              error: _aiError,
              hasReading: reading != null,
              hasActiveCrop: _hasActiveCrop,
            ),
            const SizedBox(height: 20),
            _QuickStats(
              reading: shown,
              planting: planting,
              sensorCount: watched.length,
              onOpenFarm: () => ShellScope.maybeOf(context)?.selectTab(1),
            ),
            const SizedBox(height: 20),
            SectionHeader(
              title: shownCode == null ? 'The numbers' : 'Sensor ($shownCode)',
              icon: Icons.sensors,
            ),
            const SizedBox(height: 12),
            if (shown == null)
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
              _SensorGrid(reading: shown, crop: shownRanges),
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
              ],
            ),
          ),
        ],
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 10,
            right: 12,
            child: const _StickyBell(),
          ),
        ],
      ),
    );
  }
}

/// Farm picture with the moisture and weather cards sitting on its lower edge.
///
/// Overlap uses a top inset inside a [Stack], because negative padding crashes.
class _HomeStage extends StatelessWidget {
  const _HomeStage({required this.hero, this.focus});

  final Widget hero;
  final Widget? focus;

  @override
  Widget build(BuildContext context) {
    if (focus == null) return hero;
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        hero,
        Padding(
          padding: const EdgeInsets.only(top: 198, left: 16, right: 16),
          child: focus,
        ),
      ],
    );
  }
}

/// Notification bell pinned to the top-right so it stays visible on scroll.
class _StickyBell extends StatelessWidget {
  const _StickyBell();

  @override
  Widget build(BuildContext context) {
    final unread = NotificationScope.maybeOf(context)?.unreadCount ?? 0;
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      shadowColor: const Color(0x332E3230),
      child: IconButton(
        tooltip: unread == 0
            ? 'Notifications'
            : 'Notifications ($unread unread)',
        onPressed: () {
          Navigator.of(context).push(
            AppPageRoutes.slideFromRight(const NotificationsPage()),
          );
        },
        icon: Badge(
          isLabelVisible: unread > 0,
          label: Text(unread > 9 ? '9+' : '$unread'),
          backgroundColor: AppColors.error,
          textColor: Colors.white,
          child: const Icon(
            Icons.notifications_outlined,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// Farm banner with the greeting and the crop switcher button.
class _HomeHero extends StatelessWidget {
  const _HomeHero({
    required this.farmName,
    required this.nameError,
    required this.plantings,
    required this.selected,
    required this.sensors,
    required this.cropsError,
    required this.onSelectCrop,
    required this.onAddCrop,
  });

  final String? farmName;
  final Object? nameError;
  final List<Planting> plantings;
  final Planting? selected;
  final List<FarmSensor> sensors;
  final Object? cropsError;
  final ValueChanged<Planting> onSelectCrop;
  final VoidCallback onAddCrop;

  String _hello() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  /// Bottom sheet listing only crops planted on the Crops page, plus Add a crop.
  Future<void> _openCropPicker(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      showDragHandle: true,
      builder: (sheetCtx) {
        return SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetCtx).height * 0.8,
            ),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              children: [
                Text(
                  'Your crops',
                  style: GoogleFonts.literata(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                if (cropsError != null) ...[
                  Text(
                    'Could not load crops:\n$cropsError',
                    style: const TextStyle(color: AppColors.error),
                  ),
                  const SizedBox(height: 8),
                ] else if (plantings.isEmpty) ...[
                  const Text(
                    'Nothing planted yet. Add a crop to see its stats here.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                ],
                for (final p in plantings) ...[
                  _CropPickerRow(
                    planting: p,
                    sensors: [
                      for (final s in sensors)
                        if (s.plantingId == p.id) s,
                    ],
                    selected: p.id == selected?.id,
                    onTap: () {
                      Navigator.of(sheetCtx).pop();
                      onSelectCrop(p);
                    },
                  ),
                  const SizedBox(height: 8),
                ],
                _AddCropRow(
                  onTap: () {
                    Navigator.of(sheetCtx).pop();
                    onAddCrop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = (farmName == null || farmName!.trim().isEmpty)
        ? 'My farm'
        : farmName!.trim();
    final letter = name.isEmpty ? 'S' : name[0].toUpperCase();
    final crop = selected?.crop.name;
    final buttonLabel = crop ?? (plantings.isEmpty ? 'Add a crop' : name);

    return SizedBox(
      height: 250,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/farm/farm-banner.jpg',
            fit: BoxFit.cover,
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 10,
            left: 16,
            right: 16,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white,
                  child: Text(
                    letter,
                    style: const TextStyle(
                      color: AppColors.navIcon,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Right side reserved for the sticky bell; keep text clear of it.
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 52),
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_hello()} · $name',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          shadows: [
                            Shadow(color: Color(0xE6FFFFFF), blurRadius: 12),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => _openCropPicker(context),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(48, 28),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          alignment: Alignment.centerLeft,
                        ),
                        child: Text(
                          '$buttonLabel ▾',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.literata(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (nameError != null)
                        const Text(
                          'Could not load the farm name.',
                          style: TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                  ),
                ),
                // Bell is drawn by _StickyBell above the scroll area.
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One planted crop in the Home picker: picture, day count, sensor status.
class _CropPickerRow extends StatelessWidget {
  const _CropPickerRow({
    required this.planting,
    required this.sensors,
    required this.selected,
    required this.onTap,
  });

  final Planting planting;

  /// Kits placed on this crop's plot.
  final List<FarmSensor> sensors;
  final bool selected;
  final VoidCallback onTap;

  /// "Soil OK" / "Needs attention" / "No sensor yet" for the second line.
  (String, Color) _status() {
    if (sensors.isEmpty) return ('No sensor yet', AppColors.textSecondary);
    final ranges = plantingBandRanges(planting);
    final flagged = sensors.any(
      (s) =>
          s.latest != null &&
          sensorAreaFlag(s.latest!, crop: ranges) != SensorAreaFlag.ok,
    );
    if (flagged) return ('Needs attention', AppColors.error);
    final waiting = sensors.every((s) => s.latest == null);
    if (waiting) return ('Waiting for a reading', AppColors.textSecondary);
    return ('Soil OK', AppColors.navIcon);
  }

  @override
  Widget build(BuildContext context) {
    final timeline = timelineFor(planting);
    final asset = cropIllustrationAsset(planting.crop.name);
    final (status, statusColor) = _status();
    final dayLine = timeline == null
        ? 'Planted'
        : 'Day ${timeline.dayNumber} of ${timeline.totalDays}';

    return Material(
      color: selected ? AppColors.surfaceLow : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.surfaceMuted,
          width: 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: asset == null
                      ? const ColoredBox(
                          color: AppColors.surfaceMuted,
                          child: Icon(Icons.eco, color: AppColors.navIcon),
                        )
                      : Image.asset(asset, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      planting.crop.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      dayLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check, color: AppColors.navIcon, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

/// Last row of the crop picker: opens the Crops list to plant another crop.
class _AddCropRow extends StatelessWidget {
  const _AddCropRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.buttonGreen, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.add_circle_outline, color: AppColors.navIcon),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Add a crop',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.navIcon,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown instead of every Home stat when the selected crop has no sensor.
class _NoSensorCard extends StatelessWidget {
  const _NoSensorCard({
    required this.planting,
    required this.unplaced,
    required this.onAdd,
    required this.onPlace,
  });

  final Planting planting;

  /// Claimed kits that are not on any crop yet.
  final List<FarmSensor> unplaced;
  final VoidCallback onAdd;
  final ValueChanged<FarmSensor> onPlace;

  @override
  Widget build(BuildContext context) {
    final crop = planting.crop.name;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.sensors_off, color: AppColors.navIcon, size: 32),
            const SizedBox(height: 8),
            Text(
              'No sensor on $crop yet',
              style: GoogleFonts.literata(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Add a sensor to this plot to see soil readings, tips, and '
              'stats for $crop.',
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.45,
                fontWeight: FontWeight.w700,
              ),
            ),
            for (final sensor in unplaced) ...[
              const SizedBox(height: 8),
              Text(
                'Place ${sensor.label} on $crop?',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => onPlace(sensor),
                  child: Text('Place on $crop'),
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: onAdd,
                child: const Text('Add sensor'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeFocusRow extends StatelessWidget {
  const _HomeFocusRow({
    required this.reading,
    required this.weather,
    this.crop,
  });

  final SoilReading? reading;
  final WeatherSnapshot? weather;

  /// Crop range of the plot this reading came from; null = universal bands.
  final CropBandRanges? crop;

  @override
  Widget build(BuildContext context) {
    final moisture = reading?.moisturePercent;
    final temp = weather?.temperatureC;
    final label = switch (classifyMoistureBand(value: moisture, crop: crop)) {
      'missing' => 'Waiting',
      'critical_dry' || 'dry' => 'Needs water',
      'critical_wet' || 'wet' => 'Plenty of water',
      _ => 'Looking okay',
    };
    final rainTomorrow = weather != null && weather!.daily.length > 1
        ? '${weather!.daily[1].rainProbability.round()}% rain tomorrow'
        : null;
    final icon = weather == null
        ? Icons.wb_sunny
        : weatherCodeIcon(weather!.weatherCode);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SoftCard(
              expand: true,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MoistureRing(percent: moisture),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SoftCard(
              expand: true,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: const Color(0xFFE0A100)),
                  const SizedBox(height: 4),
                  Text(
                    temp == null ? '—' : '${temp.round()}°C',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.literata(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    weather?.conditionLabel ?? 'Forecast below',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (rainTomorrow != null)
                    Text(
                      rainTomorrow,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Orange ring from the mock: full muted track + colored progress arc.
class _MoistureRing extends StatelessWidget {
  const _MoistureRing({required this.percent});

  final double? percent;

  @override
  Widget build(BuildContext context) {
    final value = percent == null ? 0.0 : (percent!.clamp(0, 100) / 100);
    return SizedBox(
      width: 62,
      height: 62,
      child: CustomPaint(
        painter: _MoistureRingPainter(progress: value.toDouble()),
        child: Center(
          child: Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Text(
              percent == null ? '—' : '${percent!.round()}%',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MoistureRingPainter extends CustomPainter {
  _MoistureRingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const stroke = 8.0;
    final radius = (math.min(size.width, size.height) - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Full track so the farmer sees the ring even at 0% / low moisture.
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = const Color(0xFFEDE7DA);
    canvas.drawCircle(center, radius, track);

    if (progress <= 0) return;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFE07A3D);
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress, false, arc);
  }

  @override
  bool shouldRepaint(covariant _MoistureRingPainter old) =>
      old.progress != progress;
}

class _QuickStats extends StatelessWidget {
  const _QuickStats({
    required this.reading,
    required this.planting,
    required this.sensorCount,
    required this.onOpenFarm,
  });

  final SoilReading? reading;
  final Planting? planting;

  /// Sensors on the selected crop (or the whole farm when nothing is planted).
  final int sensorCount;
  final VoidCallback? onOpenFarm;

  @override
  Widget build(BuildContext context) {
    final timeline = planting == null ? null : timelineFor(planting!);
    final narrow = isNarrowPhone(context);
    final tiles = [
      _Stat(
        icon: Icons.sensors,
        label: 'Sensors',
        value: sensorCount == 0 ? '—' : '$sensorCount',
        onTap: onOpenFarm,
      ),
      _Stat(
        icon: Icons.water_drop_outlined,
        label: 'Soil wetness',
        value: reading?.moisturePercent == null
            ? '—'
            : '${reading!.moisturePercent!.round()}%',
      ),
      _Stat(
        icon: Icons.eco_outlined,
        label: planting?.crop.name ?? 'Harvest',
        value: timeline == null ? '—' : '${timeline.daysLeft} days',
        onTap: onOpenFarm,
      ),
      _Stat(
        icon: Icons.map_outlined,
        label: 'Farm map',
        value: 'Open',
        onTap: onOpenFarm,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Quick stats',
          style: GoogleFonts.literata(
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        if (narrow)
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            tiles[i],
          ]
        else ...[
          Row(
            children: [
              Expanded(child: tiles[0]),
              const SizedBox(width: 8),
              Expanded(child: tiles[1]),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: tiles[2]),
              const SizedBox(width: 8),
              Expanded(child: tiles[3]),
            ],
          ),
        ],
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.navIcon, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.literata(
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _SensorGrid extends StatelessWidget {
  const _SensorGrid({required this.reading, this.crop});

  final SoilReading reading;

  /// Crop range for the wetness chip; null = universal bands.
  final CropBandRanges? crop;

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
    final moistureChip =
        switch (classifyMoistureBand(value: moisture, crop: crop)) {
          'critical_dry' || 'dry' => ('Low', StatusChipTone.warn),
          'critical_wet' || 'wet' => ('High', StatusChipTone.warn),
          'ok' => (null, StatusChipTone.good),
          _ => (null, StatusChipTone.neutral),
        };
    final nChip = _rangeChip(value: nitrogen, low: 45);
    final pChip = _rangeChip(value: phosphorus, low: 20);
    final kChip = _rangeChip(value: potassium, low: 80);
    final saltChip = _rangeChip(value: salinity, high: 4);

    final tiles = [
        _MetricTile(
          icon: Icons.water_drop_outlined,
          label: 'Wetness',
          value: moisture == null ? '—' : '${moisture.toStringAsFixed(0)}%',
          chip: moistureChip.$1,
          tone: moistureChip.$2,
        ),
        _MetricTile(
          icon: Icons.thermostat,
          label: 'Temperature',
          value: reading.soilTemperatureC?.toStringAsFixed(1) ?? '—',
          unit: '°C',
        ),
        _MetricTile(
          icon: Icons.science_outlined,
          label: 'pH Level',
          value: reading.ph?.toStringAsFixed(1) ?? '—',
        ),
        _MetricTile(
          icon: Icons.bolt_outlined,
          label: 'EC',
          value: reading.ec?.toStringAsFixed(1) ?? '—',
          unit: 'dS/m',
        ),
        _MetricTile(
          icon: Icons.waves_outlined,
          label: 'Salinity',
          value: salinity?.toStringAsFixed(1) ?? '—',
          unit: 'ppt',
          chip: saltChip.$1,
          tone: saltChip.$2,
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
        ),
        _MetricTile(
          icon: Icons.eco_outlined,
          label: 'Potassium',
          value: potassium?.toStringAsFixed(0) ?? '—',
          unit: 'ppm',
          chip: kChip.$1,
          tone: kChip.$2,
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Rows size to their content (big phone fonts grow the tile instead
        // of overflowing); the two tiles in a row share the taller height.
        final cols = constraints.maxWidth < 280 ? 1 : 2;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < tiles.length; i += cols) ...[
              if (i > 0) const SizedBox(height: 8),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var j = 0; j < cols; j++) ...[
                      if (j > 0) const SizedBox(width: 8),
                      Expanded(
                        child: i + j < tiles.length
                            ? tiles[i + j]
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
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
  });

  final IconData icon;
  final String label;
  final String value;
  final String? unit;
  final String? chip;
  final StatusChipTone tone;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      expand: true,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.navIcon.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.navIcon, size: 14),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (chip != null) ...[
                const SizedBox(width: 4),
                StatusChip(label: chip!, tone: tone),
              ],
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: GoogleFonts.literata(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (unit != null) ...[
                  const SizedBox(width: 3),
                  Text(
                    unit!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
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
        const Text(
          'AI FOR THIS AREA',
          style: TextStyle(
            color: AppColors.navIcon,
            fontWeight: FontWeight.w800,
            fontSize: 12,
            letterSpacing: 0.6,
          ),
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
          if (hasActiveCrop) ...[
            _HomeTipCard(
              slotLabel: 'Nutrients',
              icon: Icons.science,
              rec: _recOf(assessment!, 'nutrient'),
            ),
            const SizedBox(height: 10),
            _HomeTipCard(
              slotLabel: 'Crop care',
              icon: Icons.eco_outlined,
              rec: _recOf(assessment!, 'crop_care'),
            ),
          ] else
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

/// One of the three Home tip slots. Tap jumps to the Farm tab (selected crop).
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
    final chipText = rec?.recommendedAction.trim();
    final title = rec?.title ?? 'Pull to refresh';
    return SoftCard(
      onTap: () => ShellScope.maybeOf(context)?.selectTab(1),
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  slotLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              if (chipText != null && chipText.isNotEmpty)
                StatusChip(label: chipText, tone: _actionTone(chipText)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.literata(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              height: 1.2,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  static StatusChipTone _actionTone(String action) {
    final lower = action.toLowerCase();
    if (lower.contains('wait') ||
        lower.contains('hold') ||
        lower.contains('okay') ||
        lower.contains('fine') ||
        lower.contains('no worry')) {
      return StatusChipTone.good;
    }
    if (lower.contains('water') ||
        lower.contains('irrigate') ||
        lower.contains('fertilizer') ||
        lower.contains('add')) {
      return StatusChipTone.warn;
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
                      ShellScope.maybeOf(context)?.selectTab(1);
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
