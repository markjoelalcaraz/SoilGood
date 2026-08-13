/// Background listener that classifies system events into farm alerts.
///
/// Started from the app shell (not a page). Watches soil Realtime, checks
/// cultivation phase, and inserts `farm_notifications`. Exposes unread counts
/// for the bell badge and bottom-nav red dots.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/ai/insights_config.dart';
import '../../crops/data/crops_repository.dart';
import '../../crops/logic/crop_timeline.dart';
import '../../home/data/soil_reading.dart';
import '../../home/data/soil_readings_repository.dart';
import '../../weather/data/farm_location_repository.dart';
import '../../weather/data/open_meteo_weather_service.dart';
import '../data/farm_notification.dart';
import '../data/notifications_repository.dart';
import 'notification_evaluator.dart';

/// Owns soil + phase subscriptions and unread badge state while in the shell.
class NotificationController extends ChangeNotifier {
  NotificationController({
    SoilReadingsRepository? soilRepo,
    FarmLocationRepository? farmRepo,
    OpenMeteoWeatherService? weatherService,
    NotificationsRepository? notificationsRepo,
    CropsRepository? cropsRepo,
    NotificationEvaluator? evaluator,
  }) : _soilRepo = soilRepo ?? SoilReadingsRepository(),
       _farmRepo = farmRepo ?? FarmLocationRepository(),
       _weatherService = weatherService ?? OpenMeteoWeatherService(),
       _notificationsRepo = notificationsRepo ?? NotificationsRepository(),
       _cropsRepo = cropsRepo ?? CropsRepository(),
       _evaluator = evaluator ?? const NotificationEvaluator();

  final SoilReadingsRepository _soilRepo;
  final FarmLocationRepository _farmRepo;
  final OpenMeteoWeatherService _weatherService;
  final NotificationsRepository _notificationsRepo;
  final CropsRepository _cropsRepo;
  final NotificationEvaluator _evaluator;

  StreamSubscription<SoilReading?>? _soilSub;
  StreamSubscription<List<FarmNotification>>? _inboxSub;
  String? _lastReadingId;
  bool _closed = false;
  List<FarmNotification> _rows = [];

  /// Unread alerts the farmer has not acknowledged yet.
  List<FarmNotification> get unread =>
      _rows.where((n) => n.isUnread).toList(growable: false);

  /// Count for the bell badge (capped display is in the widget).
  int get unreadCount => unread.length;

  /// True when [tabIndex] has at least one unread related alert.
  bool tabHasUnread(int tabIndex) {
    final types = FarmNotificationType.typesForTab(tabIndex);
    if (types.isEmpty) return false;
    return unread.any((n) => types.contains(n.type));
  }

  /// Load bands, evaluate soil + phase, then listen for Realtime.
  Future<void> start() async {
    final config = await InsightsConfig.load();
    if (_closed) return;

    _inboxSub = _notificationsRepo.watchRecent().listen(
      (rows) {
        if (_closed) return;
        _rows = rows;
        notifyListeners();
      },
      onError: (Object e, StackTrace st) {
        debugPrint('Notifications: inbox stream failed: $e\n$st');
      },
    );

    try {
      final latest = await _soilRepo.fetchLatest();
      if (!_closed && latest != null) {
        await _onReading(config, latest);
      }
    } on Object catch (e, st) {
      debugPrint('Notifications: initial evaluate failed: $e\n$st');
    }

    if (!_closed) {
      await _maybeNotifyPhase();
    }

    if (_closed) return;
    _soilSub = _soilRepo.watchLatest().listen(
      (reading) {
        if (reading == null) return;
        unawaited(_onReading(config, reading));
        unawaited(_maybeNotifyPhase());
      },
      onError: (Object e, StackTrace st) {
        debugPrint('Notifications: soil stream failed: $e\n$st');
      },
    );
  }

  /// Marks alerts that belong to [tabIndex] as read (nav tap).
  Future<void> markTabRead(int tabIndex) async {
    final types = FarmNotificationType.typesForTab(tabIndex);
    if (types.isEmpty) return;
    final ids = unread.where((n) => types.contains(n.type)).map((n) => n.id).toList();
    if (ids.isEmpty) return;

    final previous = _rows;
    final now = DateTime.now().toUtc();
    _rows = [
      for (final n in _rows)
        if (ids.contains(n.id)) n.copyWith(readAt: now) else n,
    ];
    notifyListeners();

    try {
      await _notificationsRepo.markTypesRead(types);
    } on Object catch (e, st) {
      _rows = previous;
      notifyListeners();
      debugPrint('Notifications: mark tab read failed: $e\n$st');
    }
  }

  @override
  void dispose() {
    _closed = true;
    _soilSub?.cancel();
    _inboxSub?.cancel();
    _soilSub = null;
    _inboxSub = null;
    super.dispose();
  }

  /// Skip the same reading id; classify; insert only new same-day types.
  Future<void> _onReading(InsightsConfig config, SoilReading reading) async {
    if (_closed) return;
    if (_lastReadingId == reading.id) return;
    _lastReadingId = reading.id;

    try {
      final farmId = await _farmRepo.getPrimaryFarmId();
      if (farmId == null || _closed) return;

      final weather = await _tryWeather();
      if (_closed) return;

      final facts = config.classifiedFacts(
        soilReadingId: reading.id,
        validation: reading.validationStatus,
        validationMessage: reading.validationMessage,
        moisturePercent: reading.moisturePercent,
        ph: reading.ph,
        soilTemperatureC: reading.soilTemperatureC,
        ec: reading.ec,
        salinity: reading.salinity,
        nitrogen: reading.nitrogen,
        phosphorus: reading.phosphorus,
        potassium: reading.potassium,
        rainProbToday: weather?.rainProbability,
        conditionToday: weather?.conditionLabel,
      );

      final drafts = _evaluator.evaluate(
        farmId: farmId,
        reading: reading,
        facts: facts,
        now: DateTime.now(),
      );
      if (drafts.isEmpty) return;

      final inserted = await _notificationsRepo.insertNewDrafts(drafts);
      for (final row in inserted) {
        debugPrint(
          'Notifications: saved ${row.type.wireName} (${row.severity.wireName})',
        );
      }
    } on Object catch (e, st) {
      debugPrint('Notifications: evaluate/insert failed: $e\n$st');
    }
  }

  /// Once per planting phase (not the first phase — that is not a "change").
  Future<void> _maybeNotifyPhase() async {
    if (_closed) return;
    try {
      final farmId = await _farmRepo.getPrimaryFarmId();
      if (farmId == null || _closed) return;
      final planting = await _cropsRepo.fetchActivePlanting(farmId);
      if (planting == null || _closed) return;
      final timeline = timelineFor(planting);
      if (timeline == null || timeline.currentIndex <= 0) return;

      final phase = timeline.current;
      final saved = await _notificationsRepo.insertIfNew(
        NotificationDraft(
          farmId: farmId,
          type: FarmNotificationType.phaseChange,
          severity: FarmNotificationSeverity.info,
          title: '${planting.crop.name}: ${phase.label}',
          body:
              'The crop moved into ${phase.label} '
              '(day ${timeline.dayNumber} of ${timeline.totalDays}).',
          dedupeKey: 'phase_change:${planting.id}:${phase.id}',
        ),
      );
      if (saved != null) {
        debugPrint('Notifications: saved phase_change ${phase.id}');
      }
    } on Object catch (e, st) {
      debugPrint('Notifications: phase check failed: $e\n$st');
    }
  }

  /// Weather is optional — soil alerts still run if Open-Meteo fails.
  Future<({double? rainProbability, String? conditionLabel})?> _tryWeather() async {
    try {
      final farm = await _farmRepo.getPrimaryFarmCoordinates();
      if (farm == null) return null;
      final snap = await _weatherService.fetch(
        latitude: farm.latitude,
        longitude: farm.longitude,
      );
      if (snap.daily.isEmpty) return null;
      final today = snap.daily.first;
      return (
        rainProbability: today.rainProbability,
        conditionLabel: today.conditionLabel,
      );
    } on Object catch (e) {
      debugPrint('Notifications: weather skipped: $e');
      return null;
    }
  }
}
