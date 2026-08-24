/// Crops feature page shown inside the app shell content area (third bottom-nav tab).
///
/// Two modes: no planting → 8-in-1 chips + weather + suitable catalog matches
/// for the latest soil snapshot and forecast; active planting → in-tab crop
/// plan (phases, days, Groq care). Not a pushed route — the bottom nav stays.
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
import '../../analytics/logic/manila_time.dart';
import '../../home/data/soil_reading.dart';
import '../../home/data/soil_readings_repository.dart';
import '../../shell/app_shell.dart';
import '../../weather/data/farm_location_repository.dart';
import '../../weather/data/open_meteo_weather_service.dart';
import '../../weather/data/weather_models.dart';
import '../data/crop_catalog.dart';
import '../data/crops_repository.dart';
import '../data/planting.dart';
import '../logic/crop_match.dart';
import '../logic/crop_timeline.dart';
import '../logic/crops_care_ai_client.dart';
import '../logic/crops_care_regen.dart';
import 'crop_plan_page.dart';

/// Crops tab: catalog match or the selected crop’s plan.
class CropsPage extends StatefulWidget {
  const CropsPage({super.key});

  @override
  State<CropsPage> createState() => _CropsPageState();
}

class _CropsPageState extends State<CropsPage> {
  final _cropsRepo = CropsRepository();
  final _soilRepo = SoilReadingsRepository();
  final _farmRepo = FarmLocationRepository();
  final _weatherService = OpenMeteoWeatherService();
  final _aiRepo = SavedAssessmentRepository();
  final _groq = CropsCareAiClient();

  bool _started = false;
  bool _loadDone = false;

  String? _farmId;
  Planting? _planting;
  SoilReading? _reading;
  List<CropCatalogEntry> _catalog = [];
  WeatherSnapshot? _weather;
  Object? _weatherError;

  Object? _loadError;
  Object? _actionError;

  SavedAssessment? _assessment;
  Object? _aiError;
  bool _aiLoading = false;

  /// IndexedStack builds this tab offstage. Wait until visible so Groq is not
  /// billed on every app open.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started && TickerMode.valuesOf(context).enabled) {
      _started = true;
      _reloadAll();
    }
  }

  /// Refetches farm, planting, soil, catalog, and weather; then care AI if planted.
  Future<void> _reloadAll() async {
    Object? err;
    String? farmId;
    Planting? planting;
    SoilReading? reading;
    List<CropCatalogEntry> catalog = [];
    WeatherSnapshot? weather;

    try {
      farmId = await withRefreshTimeout(_farmRepo.getPrimaryFarmId());
      final id = farmId;
      if (id == null) {
        throw StateError('No farm found. Finish onboarding first.');
      }
      await Future.wait([
        () async {
          planting = await withRefreshTimeout(
            _cropsRepo.fetchActivePlanting(id),
          );
        }(),
        () async {
          reading = await withRefreshTimeout(_soilRepo.fetchLatest());
        }(),
        () async {
          catalog = await withRefreshTimeout(_cropsRepo.fetchCatalog());
        }(),
      ]);
    } on Object catch (e) {
      err = e;
    }

    Object? weatherErr;
    if (err == null) {
      try {
        weather = await withRefreshTimeout(_fetchWeather());
      } on Object catch (e) {
        weatherErr = e;
      }
    }

    if (!mounted) return;
    setState(() {
      _loadDone = true;
      if (err == null) {
        _farmId = farmId;
        _planting = planting;
        _reading = reading;
        _catalog = catalog;
        _loadError = null;
        if (weatherErr == null) {
          _weather = weather;
          _weatherError = null;
        } else {
          _weatherError = weatherErr;
        }
      } else {
        _loadError = err;
      }
    });

    if (err == null && planting != null && reading != null) {
      await _loadCareAi();
    } else if (mounted) {
      setState(() {
        _assessment = planting == null ? null : _assessment;
        if (planting == null) {
          _aiError = null;
          _aiLoading = false;
        }
      });
    }
  }

  Future<WeatherSnapshot?> _fetchWeather() async {
    final farm = await _farmRepo.getPrimaryFarmCoordinates();
    if (farm == null) return null;
    return _weatherService.fetch(
      latitude: farm.latitude,
      longitude: farm.longitude,
    );
  }

  Future<void> _loadCareAi() async {
    final farmId = _farmId;
    final planting = _planting;
    final reading = _reading;
    if (farmId == null || planting == null || reading == null) return;
    if (planting.id == 'pending') return;

    final timeline = timelineFor(planting);
    if (timeline == null) {
      if (!mounted) return;
      setState(() {
        _aiError = StateError(
          'Crop catalog is missing phases. Run supabase_crops_home_ai.sql.',
        );
        _aiLoading = false;
      });
      return;
    }

    setState(() => _aiLoading = true);

    try {
      final insights = await InsightsConfig.load();
      final saved = await withRefreshTimeout(
        _aiRepo.fetchLatest(
          farmId: farmId,
          kind: 'crops',
          plantingId: planting.id,
        ),
      );

      if (!shouldRegenCropsCareAi(
        saved: saved,
        plantingId: planting.id,
        soilReadingId: reading.id,
        promptVersion: insights.promptVersion,
        timeline: timeline,
      )) {
        if (!mounted) return;
        setState(() {
          _assessment = saved;
          _aiError = null;
          _aiLoading = false;
        });
        return;
      }

      final generated = await _groq.generate(
        insights: insights,
        reading: reading,
        planting: planting,
        timeline: timeline,
        weather: _weather,
      );
      final validUntil = DateTime.now().add(
        Duration(hours: insights.cropsCacheHours),
      );
      final savedNew = await withRefreshTimeout(
        _aiRepo.save(
          farmId: farmId,
          kind: 'crops',
          plantingId: planting.id,
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

  /// Confirm, then optimistic plan + insert. Blocks while a select is pending.
  Future<void> _selectCrop(CropCatalogEntry crop) async {
    final farmId = _farmId;
    if (farmId == null) return;
    // Already planted or mid-insert — avoid double-tap duplicate actives.
    if (_planting != null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Plant ${crop.name} today?'),
        content: const Text(
          'This starts a cultivation plan for this crop on your farm.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Select crop'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    // Second guard after the dialog (another tap may have started meanwhile).
    if (_planting != null) return;

    final today = manilaCalendarDate(DateTime.now());
    final days = crop.daysToMaturity;
    final optimistic = Planting(
      id: 'pending',
      farmId: farmId,
      cropId: crop.id,
      status: 'active',
      plantedAt: today,
      expectedHarvestAt: days == null ? null : today.add(Duration(days: days)),
      crop: crop,
    );
    setState(() {
      _planting = optimistic;
      _actionError = null;
      _assessment = null;
    });

    try {
      final saved = await _cropsRepo.selectCrop(farmId: farmId, crop: crop);
      if (!mounted) return;
      setState(() => _planting = saved);
      try {
        final weather = await _fetchWeather();
        if (mounted) setState(() => _weather = weather);
      } on Object {
        // Care AI still runs with missing rain facts.
      }
      await _loadCareAi();
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _planting = null;
        _actionError = e;
      });
    }
  }

  Future<void> _changeCrop() async {
    final planting = _planting;
    if (planting == null || planting.id == 'pending') return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change crop?'),
        content: const Text(
          'This ends the current plan and shows suitable crops again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Change crop'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final previous = planting;
    final previousAi = _assessment;
    setState(() {
      _planting = null;
      _assessment = null;
      _actionError = null;
    });

    try {
      await _cropsRepo.endPlanting(previous.id);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _planting = previous;
        _assessment = previousAi;
        _actionError = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final waitingFirst = !_loadDone && _loadError == null;
    final planting = _planting;
    final reading = _reading;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const SoilGoodTopBar(title: 'Crops', leadingIcon: Icons.eco),
      body: AppRefreshScroll(
        onRefresh: _reloadAll,
        children: [
          Text(
            planting == null ? 'Crop Matches' : 'Crop Plan',
            style: GoogleFonts.literata(
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            planting == null
                ? 'Crops that fit your latest soil snapshot and this week’s weather.'
                : 'Timeline and care for the crop you selected.',
            style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 16),
          if (_loadError != null) ...[
            SoftCard(
              color: AppColors.errorContainer,
              child: Text(
                'Could not load crops:\n$_loadError',
                style: const TextStyle(color: Color(0xFF690005), height: 1.5),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (waitingFirst)
            const _CropsFirstLoadSkeleton()
          else if (planting != null)
            CropPlanView(
              planting: planting,
              timeline: timelineFor(planting),
              onChangeCrop: _changeCrop,
              assessment: _assessment,
              aiError: _aiError,
              aiLoading: _aiLoading,
              actionError: _actionError,
            )
          else ...[
            if (_actionError != null) ...[
              SoftCard(
                color: AppColors.errorContainer,
                child: Text(
                  '$_actionError',
                  style: const TextStyle(color: Color(0xFF690005), height: 1.5),
                ),
              ),
              const SizedBox(height: 12),
            ],
            _SoilSnapshotCard(reading: reading),
            const SizedBox(height: 12),
            _WeatherSnapshotCard(
              weather: _weather,
              error: _weatherError,
            ),
            const SizedBox(height: 20),
            const SectionHeader(title: 'Suitable crops'),
            const SizedBox(height: 12),
            ..._matchList(reading),
          ],
        ],
      ),
    );
  }

  List<Widget> _matchList(SoilReading? reading) {
    if (reading == null) {
      return const [
        SoftCard(
          child: Text(
            'No soil reading yet.\nLink a device and wait for a snapshot before matching crops.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.5),
          ),
        ),
      ];
    }
    if (_catalog.isEmpty) {
      return const [
        SoftCard(
          child: Text(
            'Crop catalog is empty. Run supabase_schema.sql (and supabase_crops_home_ai.sql).',
            style: TextStyle(color: AppColors.textSecondary, height: 1.5),
          ),
        ),
      ];
    }

    final suitable = suitableMatches(
      scoreCropMatches(
        reading: reading,
        catalog: _catalog,
        weather: _weather,
      ),
    );
    if (suitable.isEmpty) {
      return const [
        SoftCard(
          child: Text(
            'No catalog crop fits this soil and weather at 50% or better. Improve soil first, or pull after a new reading.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.5),
          ),
        ),
      ];
    }

    final widgets = <Widget>[];
    for (var i = 0; i < suitable.length; i++) {
      if (i > 0) widgets.add(const SizedBox(height: 14));
      final m = suitable[i];
      widgets.add(
        _CropMatchCard(
          name: m.crop.name,
          scientific: m.crop.scientificName ?? '',
          matchPercent: m.percent,
          reason: m.reason,
          accent: i.isOdd ? AppColors.tertiary : AppColors.primary,
          onSelect: () => _selectCrop(m.crop),
        ),
      );
    }
    return widgets;
  }
}

class _SoilSnapshotCard extends StatelessWidget {
  const _SoilSnapshotCard({required this.reading});

  final SoilReading? reading;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current soil snapshot',
            style: GoogleFonts.literata(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          if (reading == null)
            const Text(
              'Waiting for a reading.',
              style: TextStyle(color: AppColors.textSecondary),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _chips(reading!),
            ),
        ],
      ),
    );
  }

  List<Widget> _chips(SoilReading r) {
    StatusChipTone tone({required bool warn}) =>
        warn ? StatusChipTone.warn : StatusChipTone.good;

    final chips = <Widget>[];
    void add(String? label, {bool warn = false}) {
      if (label == null) return;
      chips.add(StatusChip(label: label, tone: tone(warn: warn)));
    }

    final m = r.moisturePercent;
    add(
      m == null ? null : 'Moisture ${m.toStringAsFixed(0)}%',
      warn: m != null && (m < 30 || m > 85),
    );
    add(r.ph == null ? null : 'pH ${r.ph!.toStringAsFixed(1)}');
    final t = r.soilTemperatureC;
    add(
      t == null ? null : '${t.toStringAsFixed(0)}°C',
      warn: t != null && (t < 15 || t > 35),
    );
    add(r.ec == null ? null : 'EC ${r.ec!.toStringAsFixed(1)}');
    final salt = r.salinity;
    add(
      salt == null ? null : 'Salt ${salt.toStringAsFixed(1)} ppt',
      warn: salt != null && salt > 4,
    );
    final n = r.nitrogen;
    add(n == null ? null : 'N ${n.toStringAsFixed(0)}', warn: n != null && n < 45);
    final p = r.phosphorus;
    add(p == null ? null : 'P ${p.toStringAsFixed(0)}', warn: p != null && p < 20);
    final k = r.potassium;
    add(k == null ? null : 'K ${k.toStringAsFixed(0)}', warn: k != null && k < 80);

    if (chips.isEmpty) {
      chips.add(const StatusChip(label: 'No numeric values on this row'));
    }
    return chips;
  }
}

/// Short forecast chips used in the crop-match score (not Home’s forecast strip).
class _WeatherSnapshotCard extends StatelessWidget {
  const _WeatherSnapshotCard({this.weather, this.error});

  final WeatherSnapshot? weather;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      color: error != null && weather == null
          ? AppColors.errorContainer
          : AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weather this week',
            style: GoogleFonts.literata(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          if (weather != null)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _chips(weather!),
            )
          else if (error == null)
            const Text(
              'No farm pin yet. Save location in Profile so weather can rank crops.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.5),
            ),
          if (error != null) ...[
            if (weather != null) const SizedBox(height: 8),
            Text(
              'Could not refresh weather. Crop match uses last-known weather or soil only.\n$error',
              style: TextStyle(
                color: weather != null
                    ? AppColors.textSecondary
                    : const Color(0xFF690005),
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _chips(WeatherSnapshot w) {
    var maxProb = 0.0;
    var rainSum = 0.0;
    final days = w.daily.take(3);
    var n = 0;
    for (final d in days) {
      if (d.rainProbability > maxProb) maxProb = d.rainProbability;
      rainSum += d.rainfallMm;
      n++;
    }

    return [
      StatusChip(
        label: 'Air ${w.temperatureC.toStringAsFixed(0)}°C',
        tone: w.temperatureC < 15 || w.temperatureC > 35
            ? StatusChipTone.warn
            : StatusChipTone.good,
      ),
      StatusChip(label: w.conditionLabel),
      if (n > 0) ...[
        StatusChip(
          label: 'Rain ${maxProb.toStringAsFixed(0)}%',
          tone: maxProb >= 60 ? StatusChipTone.good : StatusChipTone.neutral,
        ),
        StatusChip(label: '${rainSum.toStringAsFixed(0)} mm / 3d'),
      ],
      StatusChip(
        label: isPhWetSeason() ? 'PH wet season' : 'PH dry season',
      ),
    ];
  }
}

class _CropMatchCard extends StatelessWidget {
  const _CropMatchCard({
    required this.name,
    required this.scientific,
    required this.matchPercent,
    required this.reason,
    required this.onSelect,
    this.accent = AppColors.primary,
  });

  final String name;
  final String scientific;
  final int matchPercent;
  final String reason;
  final VoidCallback onSelect;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      color: AppColors.surface,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 140,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              gradient: LinearGradient(
                colors: [
                  accent.withValues(alpha: 0.85),
                  AppColors.primary.withValues(alpha: 0.65),
                ],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Icon(
                    Icons.eco,
                    size: 72,
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$matchPercent% Match',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 100,
                  bottom: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.literata(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (scientific.isNotEmpty)
                        Text(
                          scientific,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SoftCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lightbulb_outline, color: accent, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          reason,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontStyle: FontStyle.italic,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: onSelect,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Select crop',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward, size: 18),
                      ],
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

class _CropsFirstLoadSkeleton extends StatelessWidget {
  const _CropsFirstLoadSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        SoftCard(color: AppColors.surfaceMuted, child: SizedBox(height: 88)),
        SizedBox(height: 16),
        SoftCard(color: AppColors.surfaceMuted, child: SizedBox(height: 180)),
        SizedBox(height: 14),
        SoftCard(color: AppColors.surfaceMuted, child: SizedBox(height: 180)),
      ],
    );
  }
}
