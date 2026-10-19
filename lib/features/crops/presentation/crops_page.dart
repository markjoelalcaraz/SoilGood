/// Pushed crop-match page, the last step of the Add a crop wizard (outside
/// the app shell).
///
/// Ranks catalog crops for one new plot using that plot's own sensor reading,
/// its soil (series, or texture as fallback), and this week's weather. Crops
/// already growing on the farm are left out. Planting saves the plot soil on
/// the planting, places the plot's sensor on it, selects the new crop, and
/// closes with `true`.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/ai/groq_chat_client.dart';
import '../../../core/ai/insights_config.dart';
import '../../../core/ai/saved_assessment_repository.dart';
import '../../../core/soil/farm_soil_display_row.dart';
import '../../../core/soil/farm_soil_label.dart';
import '../../../core/soil/soil_series.dart';
import '../../../core/soil/soil_texture.dart';
import '../../../core/live/farm_live_hub.dart';
import '../../../core/live/live_page.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/data/refresh_timeout.dart';
import '../../../shared/widgets/app_refresh_scroll.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../farm/data/plot_sensors_repository.dart';
import '../../home/data/soil_reading.dart';
import '../../shell/app_shell.dart';
import '../../weather/data/farm_location_repository.dart';
import '../../weather/data/open_meteo_weather_service.dart';
import '../../weather/data/weather_models.dart';
import '../data/crop_catalog.dart';
import '../data/crops_repository.dart';
import '../data/plot_draft.dart';
import '../logic/crop_match.dart';
import '../logic/crops_match_ai_client.dart';
import '../logic/crops_match_regen.dart';
import '../logic/selected_crop.dart';

/// Crop matches for [plot]. Pops `true` after a new crop is planted.
class CropsPage extends StatefulWidget {
  const CropsPage({required this.plot, super.key});

  /// Soil + sensor answers from the wizard.
  final PlotDraft plot;

  @override
  State<CropsPage> createState() => _CropsPageState();
}

class _CropsPageState extends State<CropsPage> with LivePage {
  final _cropsRepo = CropsRepository();
  final _sensorsRepo = PlotSensorsRepository();
  final _farmRepo = FarmLocationRepository();
  final _weatherService = OpenMeteoWeatherService();
  final _aiRepo = SavedAssessmentRepository();
  final _matchAi = CropsMatchAiClient();

  bool _started = false;
  bool _loadDone = false;

  String? _farmId;
  SoilTexture? _farmSoilTexture;
  SoilSeries? _farmSoilSeries;

  /// Catalog ids already growing on this farm (hidden from the list).
  Set<String> _plantedCropIds = {};
  SoilReading? _reading;
  List<CropCatalogEntry> _catalog = [];
  WeatherSnapshot? _weather;
  Object? _weatherError;

  Object? _loadError;
  Object? _actionError;
  bool _selecting = false;

  @override
  Set<LiveSource> get liveSources => const {
    LiveSource.plantings,
    LiveSource.soil,
    LiveSource.farms,
    LiveSource.assessments,
    LiveSource.crops,
  };

  /// A match input changed. Skip while a plant confirm is in flight.
  @override
  Future<void> onLive(Set<LiveSource> changed) async {
    if (_selecting) return;
    await _reloadAll();
  }

  /// AI catalog matches for list mode; null means use local fallback scores.
  List<CropMatch>? _aiMatches;
  Object? _matchAiError;
  bool _matchAiLoading = false;

  /// Loads once this pushed page is on screen so match AI is not billed early.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started && TickerMode.valuesOf(context).enabled) {
      _started = true;
      _reloadAll();
    }
  }

  /// Refetches farm, planted crops, this plot's newest reading, catalog, and
  /// weather, then match AI. Soil comes from the wizard (series, else texture).
  Future<void> _reloadAll() async {
    Object? err;
    String? farmId;
    final plot = widget.plot;
    final farmSoilTexture = plot.texture;
    final farmSoilSeries = plot.series;
    Set<String> plantedIds = {};
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
          final active = await withRefreshTimeout(
            _cropsRepo.fetchActivePlantings(id),
          );
          plantedIds = {for (final p in active) p.cropId};
        }(),
        () async {
          final newer = await withRefreshTimeout(
            _sensorsRepo.fetchReadingSince(
              deviceId: plot.deviceId,
              since: plot.reading.recordedAt,
            ),
          );
          // Kit is not on this plot yet, so use the texture picked in the wizard.
          reading = (newer ?? plot.reading).withWetness(plot.texture);
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
        _farmSoilTexture = farmSoilTexture;
        _farmSoilSeries = farmSoilSeries;
        _plantedCropIds = plantedIds;
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

    if (err == null && reading != null) {
      await _loadMatchAi();
    }
  }

  /// Loads saved catalog match AI or regenerates when the story moved.
  Future<void> _loadMatchAi() async {
    final farmId = _farmId;
    final reading = _reading;
    if (farmId == null || reading == null) return;
    if (_catalog.isEmpty) return;

    setState(() => _matchAiLoading = true);

    try {
      final insights = await InsightsConfig.load();
      final fingerprint = buildCropsMatchStoryFingerprint(
        reading: reading,
        weather: _weather,
        farmSoilTexture: _farmSoilTexture,
        farmSoilSeries: _farmSoilSeries,
      );
      final saved = await withRefreshTimeout(
        _aiRepo.fetchLatest(farmId: farmId, kind: 'crops_match'),
      );

      if (!shouldRegenCropsMatchAi(
        saved: saved,
        soilReadingId: reading.id,
        promptVersion: insights.promptVersion,
        weatherFingerprint: fingerprint,
      )) {
        if (!mounted) return;
        setState(() {
          _aiMatches = cropMatchesFromAssessment(
            assessment: saved!,
            catalog: _catalog,
          );
          _matchAiError = null;
          _matchAiLoading = false;
        });
        return;
      }

      final generated = await _matchAi.generate(
        insights: insights,
        reading: reading,
        catalog: _catalog,
        weather: _weather,
        farmSoilTexture: _farmSoilTexture,
        farmSoilSeries: _farmSoilSeries,
      );
      final overview = encodeCropsMatchOverview(
        fingerprint: fingerprint,
        overview: generated.overview,
      );
      final validUntil = DateTime.now().add(
        Duration(hours: insights.cropsMatchCacheHours),
      );
      final savedNew = await withRefreshTimeout(
        _aiRepo.save(
          farmId: farmId,
          kind: 'crops_match',
          soilReadingId: reading.id,
          overview: overview,
          soilHealthScore: null,
          modelName: kGroqModel,
          promptVersion: insights.promptVersion,
          validUntil: validUntil,
          recommendations: generated.recommendations,
        ),
      );
      if (!mounted) return;
      setState(() {
        _aiMatches = cropMatchesFromAssessment(
          assessment: savedNew,
          catalog: _catalog,
        );
        _matchAiError = null;
        _matchAiLoading = false;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        // Keep last AI matches if any; null means _matchList uses local scores.
        _matchAiError = e;
        _matchAiLoading = false;
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

  /// Confirm, plant the crop as a new plot, select it, then close.
  Future<void> _selectCrop(CropCatalogEntry crop) async {
    final farmId = _farmId;
    if (farmId == null) return;
    if (_selecting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Plant ${crop.name} today?'),
        content: const Text(
          'This adds a new crop plot on your farm with its own plan. '
          'Your other crops stay as they are.',
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
    if (confirmed != true || !mounted) return;
    if (_selecting) return;

    setState(() {
      _selecting = true;
      _actionError = null;
    });

    final plot = widget.plot;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final planted = await _cropsRepo.selectCrop(
        farmId: farmId,
        crop: crop,
        soilTexture: plot.texture,
        soilSeries: plot.series,
        soilSeriesOther: plot.seriesOther,
      );
      await SelectedCrop.instance.select(planted.id);
      // Crop exists now; a failed placement must not hide that, so report and close.
      try {
        await _sensorsRepo.placeOnPlot(
          deviceId: plot.deviceId,
          plantingId: planted.id,
        );
      } on Object catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '${crop.name} is planted, but Sensor (${plot.claimCode}) '
              'could not be placed: ${e is StateError ? e.message : e}. '
              'Use Add sensor on Home.',
            ),
          ),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _selecting = false;
        _actionError = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final waitingFirst = !_loadDone && _loadError == null;
    final reading = _reading;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const SoilGoodTopBar(title: 'Choose a crop', leadingIcon: Icons.eco),
      body: AppRefreshScroll(
        onRefresh: _reloadAll,
        children: [
          Text(
            'Crops for this plot',
            style: GoogleFonts.literata(
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Based on Sensor (${widget.plot.claimCode}), this plot’s soil, '
            'and this week’s weather.'
            '${_plantedCropIds.isEmpty ? '' : ' Crops already growing are not listed.'}',
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
          else ...[
            if (_selecting) ...[
              const SoftCard(
                child: Text(
                  'Planting this crop…',
                  style: TextStyle(color: AppColors.textSecondary, height: 1.5),
                ),
              ),
              const SizedBox(height: 12),
            ],
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
            // Display-only: this plot's texture · series from the wizard.
            FarmSoilDisplayRow(
              texture: _farmSoilTexture,
              series: _farmSoilSeries,
            ),
            if (farmSoilDisplayLabel(
                  texture: _farmSoilTexture,
                  series: _farmSoilSeries,
                ) !=
                null)
              const SizedBox(height: 12),
            _SoilSnapshotCard(
              reading: reading,
              title: 'Sensor (${widget.plot.claimCode}) right now',
            ),
            const SizedBox(height: 12),
            _WeatherSnapshotCard(
              weather: _weather,
              error: _weatherError,
            ),
            const SizedBox(height: 20),
            const SectionHeader(title: 'Suitable crops'),
            const SizedBox(height: 12),
            if (_matchAiError != null) ...[
              SoftCard(
                color: AppColors.errorContainer,
                child: Text(
                  'AI match unavailable — showing local scores.\n$_matchAiError',
                  style: const TextStyle(color: Color(0xFF690005), height: 1.5),
                ),
              ),
              const SizedBox(height: 12),
            ] else if (_matchAiLoading && _aiMatches == null) ...[
              const SoftCard(
                child: Text(
                  'Scoring crops for this soil and weather…',
                  style: TextStyle(color: AppColors.textSecondary, height: 1.5),
                ),
              ),
              const SizedBox(height: 12),
            ],
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

    // Prefer AI scores when loaded; fall back to local only when AI never loaded.
    final scored = _aiMatches ??
        suitableMatches(
          scoreCropMatches(
            reading: reading,
            catalog: _catalog,
            weather: _weather,
            farmSoilTexture: _farmSoilTexture,
            farmSoilSeries: _farmSoilSeries,
          ),
        );
    final suitable = [
      for (final m in scored)
        if (!_plantedCropIds.contains(m.crop.id)) m,
    ];

    if (_matchAiLoading && _aiMatches == null && _matchAiError == null) {
      return const [];
    }

    if (suitable.isEmpty) {
      return const [
        SoftCard(
          child: Text(
            'No catalog crops scored for this soil and weather. Pull after a new reading, or check the crop catalog.',
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
  const _SoilSnapshotCard({required this.reading, required this.title});

  final SoilReading? reading;
  final String title;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
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
      m == null ? null : 'Wetness ${m.toStringAsFixed(0)}%',
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
