/// Crop plan block shown under a focused area on the Farm tab.
///
/// Loads the same Home tips saved for this farm (`kind=home`), plus the water week.
///
/// The tips follow the farm and its active crop, so this area and Home share one
/// assessment. Groq runs only when that story changed. Not a route.
library;

import 'package:flutter/material.dart';

import '../../../core/ai/crop_band_classify.dart';
import '../../../core/ai/groq_chat_client.dart';
import '../../../core/ai/insights_config.dart';
import '../../../core/ai/saved_assessment.dart';
import '../../../core/ai/saved_assessment_repository.dart';
import '../../../core/live/farm_live_hub.dart';
import '../../../core/live/live_page.dart';
import '../../../shared/data/refresh_timeout.dart';
import '../../analytics/data/soil_history_repository.dart';
import '../../analytics/logic/manila_time.dart';
import '../../home/data/soil_reading.dart';
import '../../home/data/soil_readings_repository.dart';
import '../../home/logic/home_ai_client.dart';
import '../../home/logic/home_ai_regen.dart';
import '../../home/logic/home_ai_story.dart';
import '../../weather/data/farm_location_repository.dart';
import '../../weather/data/open_meteo_weather_service.dart';
import '../../weather/data/weather_models.dart';
import '../data/crops_repository.dart';
import '../data/irrigation_plan.dart';
import '../data/irrigation_plan_repository.dart';
import '../data/planting.dart';
import '../logic/crop_timeline.dart';
import '../logic/irrigation_plan_builder.dart';
import 'crop_plan_page.dart';

/// Phases, water week, and care for [planting], refreshed when
/// [refreshGeneration] changes (Farm pull-to-refresh).
class CropPlanPanel extends StatefulWidget {
  const CropPlanPanel({
    required this.planting,
    required this.refreshGeneration,
    required this.onPlantingEnded,
    super.key,
  });

  final Planting planting;

  /// Bumped by the parent after a pull so this panel refetches care and water.
  final int refreshGeneration;

  /// Runs after the active planting is ended. The parent reloads its crop.
  final Future<void> Function() onPlantingEnded;

  @override
  State<CropPlanPanel> createState() => _CropPlanPanelState();
}

class _CropPlanPanelState extends State<CropPlanPanel> with LivePage {
  final _cropsRepo = CropsRepository();
  final _soilRepo = SoilReadingsRepository();
  final _farmRepo = FarmLocationRepository();
  final _weatherService = OpenMeteoWeatherService();
  final _aiRepo = SavedAssessmentRepository();
  final _homeAi = HomeAiClient();
  final _planRepo = IrrigationPlanRepository();
  final _historyRepo = SoilHistoryRepository();
  final _planBuilder = IrrigationPlanBuilder();

  SoilReading? _reading;
  WeatherSnapshot? _weather;
  SavedAssessment? _assessment;
  Object? _aiError;
  bool _aiLoading = false;
  IrrigationPlan? _irrigationPlan;
  Object? _irrigationError;
  bool _markingWater = false;
  Object? _actionError;

  /// Ignores a slow refresh when a newer load already started.
  int _ticket = 0;

  @override
  Set<LiveSource> get liveSources => const {
    LiveSource.soil,
    LiveSource.assessments,
    LiveSource.irrigation,
    LiveSource.plantings,
  };

  /// Soil, care, or the water week changed. Keep the plan text, then reload.
  @override
  Future<void> onLive(Set<LiveSource> changed) => _load();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(CropPlanPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final cropChanged = widget.planting.id != oldWidget.planting.id;
    final pulled = widget.refreshGeneration != oldWidget.refreshGeneration;
    if (cropChanged) {
      _assessment = null;
      _irrigationPlan = null;
      _aiError = null;
      _irrigationError = null;
      _actionError = null;
      _aiLoading = true;
    }
    if (cropChanged || pulled) _load();
  }

  /// Soil, weather, saved care, and the water plan. Keeps the last plan on pull.
  Future<void> _load() async {
    final ticket = ++_ticket;
    final planting = widget.planting;
    if (planting.id == 'pending') return;

    SoilReading? reading;
    try {
      reading = await withRefreshTimeout(_soilRepo.fetchLatest());
    } on Object catch (e) {
      if (!mounted || ticket != _ticket) return;
      setState(() {
        _aiError = e;
        _aiLoading = false;
        _irrigationError = e;
      });
      return;
    }
    if (!mounted || ticket != _ticket) return;
    if (reading == null) {
      setState(() {
        _aiError = StateError('No soil reading yet.');
        _aiLoading = false;
        _irrigationError = StateError('No soil reading yet.');
      });
      return;
    }

    var weather = _weather;
    try {
      final farm = await withRefreshTimeout(
        _farmRepo.getPrimaryFarmCoordinates(),
      );
      if (farm != null) {
        weather = await withRefreshTimeout(
          _weatherService.fetch(
            latitude: farm.latitude,
            longitude: farm.longitude,
          ),
        );
      }
    } on Object {
      // Last weather stays. Care and the water plan still run.
    }
    if (!mounted || ticket != _ticket) return;
    _reading = reading;
    _weather = weather;

    await Future.wait([
      _loadHomeAi(ticket),
      _ensureIrrigationPlan(ticket),
    ]);
  }

  /// Same Home tips as the farm's saved `kind=home` row. Groq only if that story moved.
  Future<void> _loadHomeAi(int ticket) async {
    final planting = widget.planting;
    final reading = _reading;
    if (reading == null || planting.id == 'pending') return;

    final timeline = timelineFor(planting);
    if (mounted && _assessment == null) {
      setState(() => _aiLoading = true);
    }

    try {
      final insights = await InsightsConfig.load();
      final phaseId = timeline?.current.id;
      final cropRanges = CropBandRanges.fromCrop(
        planting.crop,
        phaseId: phaseId,
      );
      final fingerprint = buildHomeStoryFingerprint(
        insights: insights,
        reading: reading,
        weather: _weather,
        cropName: planting.crop.name,
        phaseId: phaseId,
        cropRanges: cropRanges,
      );
      final saved = await withRefreshTimeout(
        _aiRepo.fetchLatest(farmId: planting.farmId, kind: 'home'),
      );

      if (!shouldRegenHomeAi(
        saved: saved,
        promptVersion: insights.promptVersion,
        currentFingerprint: fingerprint,
      )) {
        if (!mounted || ticket != _ticket) return;
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
        cropName: planting.crop.name,
        phaseId: phaseId,
        phaseLabel: timeline?.current.label,
        cropRanges: cropRanges,
      );
      final validUntil = DateTime.now().add(
        Duration(hours: insights.homeCacheHours),
      );
      final savedNew = await withRefreshTimeout(
        _aiRepo.save(
          farmId: planting.farmId,
          kind: 'home',
          plantingId: planting.id,
          soilReadingId: reading.id,
          overview: encodeHomeOverviewWithFingerprint(
            fingerprint: fingerprint,
            overview: generated.overview,
          ),
          soilHealthScore: generated.soilHealthScore,
          modelName: kGroqModel,
          promptVersion: insights.promptVersion,
          validUntil: validUntil,
          recommendations: generated.recommendations,
        ),
      );
      if (!mounted || ticket != _ticket) return;
      setState(() {
        _assessment = savedNew;
        _aiError = null;
        _aiLoading = false;
      });
    } on Object catch (e) {
      if (!mounted || ticket != _ticket) return;
      setState(() {
        _aiError = e;
        _aiLoading = false;
      });
    }
  }

  /// Rebuilds the rolling water plan when its story fingerprint moves.
  Future<void> _ensureIrrigationPlan(int ticket) async {
    final planting = widget.planting;
    final reading = _reading;
    if (reading == null || planting.id == 'pending') return;

    try {
      final timeline = timelineFor(planting);
      final today = manilaCalendarDate(DateTime.now());
      final lastDay = await withRefreshTimeout(
        _planRepo.fetchLastIrrigationDay(
          farmId: planting.farmId,
          plantingId: planting.id,
        ),
      );

      double? drying;
      try {
        final start = DateTime(today.year, today.month, today.day - 4);
        final buckets = await withRefreshTimeout(
          _historyRepo.fetchDaily(start: start, end: today),
        );
        final moistures = buckets
            .where((b) => b.avgMoisture != null)
            .map((b) => b.avgMoisture!)
            .toList();
        drying = IrrigationPlanBuilder.dryingPerDay(moistures);
      } on Object {
        drying = null;
      }

      final cropRanges = CropBandRanges.fromCrop(
        planting.crop,
        phaseId: timeline?.current.id,
      );
      final moistureBand = classifyMoistureBand(
        value: reading.moisturePercent,
        crop: cropRanges,
      );
      final rainStory = IrrigationPlanBuilder.rainStoryToken(_weather);
      final fingerprint = IrrigationPlanBuilder.storyFingerprint(
        moistureBand: moistureBand,
        dryingPerDay: drying,
        rainStory: rainStory,
        phaseId: timeline?.current.id,
        lastIrrigationManilaDay: lastDay == null ? null : manilaIsoDate(lastDay),
      );

      final existing = await withRefreshTimeout(
        _planRepo.fetchLatest(farmId: planting.farmId, plantingId: planting.id),
      );

      IrrigationPlan plan;
      if (!_planRepo.needsRebuild(
        plan: existing,
        fingerprint: fingerprint,
        todayManila: today,
      )) {
        plan = existing!;
      } else {
        final drafts = _planBuilder.build(
          reading: reading,
          weather: _weather,
          phaseLabel: timeline?.current.label,
          lastIrrigationManilaDay: lastDay,
          dryingPerDay: drying,
        );
        plan = await withRefreshTimeout(
          _planRepo.savePlan(
            farmId: planting.farmId,
            plantingId: planting.id,
            horizonStart: today,
            storyFingerprint: fingerprint,
            drafts: drafts,
            previous: existing,
          ),
        );
      }

      if (!mounted || ticket != _ticket) return;
      setState(() {
        _irrigationPlan = plan;
        _irrigationError = null;
      });
    } on Object catch (e) {
      if (!mounted || ticket != _ticket) return;
      setState(() => _irrigationError = e);
    }
  }

  /// Logs Mark watered for today's water slot, then reloads the week.
  Future<void> _markWatered() async {
    final planting = widget.planting;
    final plan = _irrigationPlan;
    if (plan == null || planting.id == 'pending') return;

    final today = manilaCalendarDate(DateTime.now());
    final slot = plan.slotFor(today);
    if (slot == null || slot.isLogged) return;
    if (slot.action != IrrigationSlotAction.water) return;

    setState(() {
      _markingWater = true;
      _irrigationError = null;
    });
    try {
      await withRefreshTimeout(
        _planRepo.markWatered(
          farmId: planting.farmId,
          plantingId: planting.id,
          slot: slot,
        ),
      );
      await _ensureIrrigationPlan(_ticket);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _irrigationError = e);
    } finally {
      if (mounted) setState(() => _markingWater = false);
    }
  }

  /// Confirms, ends the planting, then asks the parent to show the crop list.
  Future<void> _changeCrop() async {
    final planting = widget.planting;
    if (planting.id == 'pending') return;

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
    if (confirmed != true || !mounted) return;

    try {
      await _cropsRepo.endPlanting(planting.id);
      if (!mounted) return;
      await widget.onPlantingEnded();
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _actionError = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final planting = widget.planting;
    return CropPlanView(
      planting: planting,
      timeline: timelineFor(planting),
      onChangeCrop: _changeCrop,
      assessment: _assessment,
      aiError: _aiError,
      aiLoading: _aiLoading,
      actionError: _actionError,
      irrigationPlan: _irrigationPlan,
      irrigationError: _irrigationError,
      markingWater: _markingWater,
      onMarkWatered: _markWatered,
    );
  }
}
