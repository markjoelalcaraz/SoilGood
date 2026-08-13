/// Pure classifier: soil + weather facts → farm alert drafts (no I/O).
///
/// Uses the same `insights.json` bands Home AI already classified. One draft
/// per type; the repository then caps that type at once per Manila calendar
/// day. Called from [NotificationController] when a new reading arrives.
library;

import '../../analytics/logic/manila_time.dart';
import '../../home/data/soil_reading.dart';
import '../data/farm_notification.dart';

/// Turns classified facts into [NotificationDraft]s. No network or database.
class NotificationEvaluator {
  const NotificationEvaluator({
    this.staleAfter = const Duration(hours: 2),
    this.skipIfRainProbPctGte = 60,
  });

  /// No new reading for this long → [FarmNotificationType.deviceOffline].
  final Duration staleAfter;

  /// Same cut as `insights.json` irrigation.skip_if_rain_prob_pct_gte.
  final double skipIfRainProbPctGte;

  /// Builds drafts for [farmId] from one reading + [InsightsConfig] facts.
  List<NotificationDraft> evaluate({
    required String farmId,
    required SoilReading reading,
    required Map<String, dynamic> facts,
    required DateTime now,
  }) {
    final ymd = _manilaYmd(now);
    final drafts = <NotificationDraft>[];

    final irrigation = _irrigation(
      farmId: farmId,
      reading: reading,
      facts: facts,
      ymd: ymd,
    );
    if (irrigation != null) drafts.add(irrigation);

    final nutrients = _nutrients(
      farmId: farmId,
      reading: reading,
      facts: facts,
      ymd: ymd,
    );
    if (nutrients != null) drafts.add(nutrients);

    final soil = _soilAlert(
      farmId: farmId,
      reading: reading,
      facts: facts,
      ymd: ymd,
    );
    if (soil != null) drafts.add(soil);

    if (reading.validationStatus != 'ok') {
      drafts.add(
        NotificationDraft(
          farmId: farmId,
          type: FarmNotificationType.sensorError,
          severity: FarmNotificationSeverity.urgent,
          title: 'Check the soil sensor',
          body: reading.validationMessage?.trim().isNotEmpty == true
              ? reading.validationMessage!.trim()
              : 'The latest reading is marked ${reading.validationStatus}.',
          dedupeKey: 'sensor_error:$ymd',
          soilReadingId: reading.id,
        ),
      );
    }

    final recorded = reading.recordedAt.isUtc
        ? reading.recordedAt
        : reading.recordedAt.toUtc();
    if (now.toUtc().difference(recorded) >= staleAfter) {
      drafts.add(
        NotificationDraft(
          farmId: farmId,
          type: FarmNotificationType.deviceOffline,
          severity: FarmNotificationSeverity.urgent,
          title: 'Sensor has not reported',
          body:
              'No new soil reading for over ${staleAfter.inHours} hours. '
              'Check the device and Wi-Fi.',
          dedupeKey: 'device_offline:$ymd',
          soilReadingId: reading.id,
        ),
      );
    }

    return drafts;
  }

  NotificationDraft? _irrigation({
    required String farmId,
    required SoilReading reading,
    required Map<String, dynamic> facts,
    required String ymd,
  }) {
    final band = facts['moisture'] as String? ?? 'missing';
    if (band == 'missing' || band == 'ok') return null;

    final moisture = _fmt(reading.moisturePercent, suffix: '%');
    final rain = (facts['rain_prob_today'] as num?)?.toDouble();

    if (band == 'dry' && rain != null && rain >= skipIfRainProbPctGte) {
      return NotificationDraft(
        farmId: farmId,
        type: FarmNotificationType.irrigation,
        severity: FarmNotificationSeverity.info,
        title: 'Rain is likely — wait to irrigate',
        body:
            'Soil is dry${moisture == null ? '' : ' ($moisture)'} but '
            'rain chance today is ${rain.toStringAsFixed(0)}%. Wait before watering.',
        dedupeKey: 'irrigation:$ymd',
        soilReadingId: reading.id,
      );
    }

    if (band == 'dry') {
      return NotificationDraft(
        farmId: farmId,
        type: FarmNotificationType.irrigation,
        severity: FarmNotificationSeverity.urgent,
        title: 'Soil is dry',
        body:
            'Moisture is low${moisture == null ? '' : ' ($moisture)'}. '
            'Irrigate today.',
        dedupeKey: 'irrigation:$ymd',
        soilReadingId: reading.id,
      );
    }

    return NotificationDraft(
      farmId: farmId,
      type: FarmNotificationType.irrigation,
      severity: FarmNotificationSeverity.warning,
      title: 'Soil is very wet',
      body:
          'Moisture is high${moisture == null ? '' : ' ($moisture)'}. '
          'Do not irrigate.',
      dedupeKey: 'irrigation:$ymd',
      soilReadingId: reading.id,
    );
  }

  NotificationDraft? _nutrients({
    required String farmId,
    required SoilReading reading,
    required Map<String, dynamic> facts,
    required String ymd,
  }) {
    final low = <String>[];
    if (facts['n_band'] == 'low') low.add('nitrogen');
    if (facts['p_band'] == 'low') low.add('phosphorus');
    if (facts['k_band'] == 'low') low.add('potassium');
    if (low.isEmpty) return null;

    return NotificationDraft(
      farmId: farmId,
      type: FarmNotificationType.nutrientLow,
      severity: FarmNotificationSeverity.warning,
      title: 'Nutrients are low',
      body: '${_joinList(low)} ${low.length == 1 ? 'is' : 'are'} low. '
          'Consider fertilizer.',
      dedupeKey: 'nutrient_low:$ymd',
      soilReadingId: reading.id,
    );
  }

  NotificationDraft? _soilAlert({
    required String farmId,
    required SoilReading reading,
    required Map<String, dynamic> facts,
    required String ymd,
  }) {
    final issues = <String>[];
    _addBandIssue(
      issues,
      band: facts['ph_band'] as String?,
      label: 'pH',
      value: _fmt(reading.ph),
    );
    _addBandIssue(
      issues,
      band: facts['temp_band'] as String?,
      label: 'Soil temperature',
      value: _fmt(reading.soilTemperatureC, suffix: '°C'),
    );
    _addBandIssue(
      issues,
      band: facts['ec_band'] as String?,
      label: 'EC',
      value: _fmt(reading.ec),
    );
    if (facts['salinity_band'] == 'high') {
      final salt = _fmt(reading.salinity, suffix: ' ppt');
      issues.add('salinity is high${salt == null ? '' : ' ($salt)'}');
    }
    if (issues.isEmpty) return null;

    return NotificationDraft(
      farmId: farmId,
      type: FarmNotificationType.soilAlert,
      severity: FarmNotificationSeverity.warning,
      title: 'Soil needs attention',
      body: '${_joinList(issues)}. Check the field before adding water or fertilizer.',
      dedupeKey: 'soil_alert:$ymd',
      soilReadingId: reading.id,
    );
  }

  void _addBandIssue(
    List<String> issues, {
    required String? band,
    required String label,
    required String? value,
  }) {
    if (band != 'low' && band != 'high') return;
    final shown = value == null ? '' : ' ($value)';
    issues.add('$label is $band$shown');
  }

  String _manilaYmd(DateTime now) {
    final day = manilaCalendarDate(now);
    final y = day.year.toString().padLeft(4, '0');
    final m = day.month.toString().padLeft(2, '0');
    final d = day.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String? _fmt(double? value, {String suffix = ''}) {
    if (value == null) return null;
    final n = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    return '$n$suffix';
  }

  String _joinList(List<String> parts) {
    if (parts.length == 1) return parts.first;
    if (parts.length == 2) return '${parts[0]} and ${parts[1]}';
    return '${parts.sublist(0, parts.length - 1).join(', ')}, and ${parts.last}';
  }
}
