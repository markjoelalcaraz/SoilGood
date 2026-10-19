/// Pure classifier: soil + weather facts → farm alert drafts (no I/O).
///
/// Uses the same crop-aware / universal bands Home AI already classified. One
/// draft per type; the repository then caps that type at once per Manila
/// calendar day. Critical moisture/temp/pH/EC/salt → urgent titles. Called
/// from [NotificationController] when a new reading arrives.
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
  ///
  /// [sensorCode] is the sticker code. When set, a low area is titled
  /// "Sensor (SG-4K91) area is low". [deviceId] keeps each kit's alert
  /// for the day, so one sensor does not hide another.
  List<NotificationDraft> evaluate({
    required String farmId,
    required SoilReading reading,
    required Map<String, dynamic> facts,
    required DateTime now,
    String? sensorCode,
    String? deviceId,
  }) {
    final ymd = _manilaYmd(now);
    final drafts = <NotificationDraft>[];

    final irrigation = _irrigation(
      farmId: farmId,
      reading: reading,
      facts: facts,
      ymd: ymd,
      sensorCode: sensorCode,
      deviceId: deviceId,
    );
    if (irrigation != null) drafts.add(irrigation);

    final nutrients = _nutrients(
      farmId: farmId,
      reading: reading,
      facts: facts,
      ymd: ymd,
      sensorCode: sensorCode,
      deviceId: deviceId,
    );
    if (nutrients != null) drafts.add(nutrients);

    final soil = _soilAlert(
      farmId: farmId,
      reading: reading,
      facts: facts,
      ymd: ymd,
      sensorCode: sensorCode,
      deviceId: deviceId,
    );
    if (soil != null) drafts.add(soil);

    if (reading.validationStatus != 'ok') {
      drafts.add(
        NotificationDraft(
          farmId: farmId,
          type: FarmNotificationType.sensorError,
          severity: FarmNotificationSeverity.urgent,
          title: _checkTitle(sensorCode),
          body: reading.validationMessage?.trim().isNotEmpty == true
              ? reading.validationMessage!.trim()
              : 'The latest reading is marked ${reading.validationStatus}.',
          dedupeKey: _dedupe('sensor_error', ymd, deviceId),
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
          title: _named(
            sensorCode,
            'Sensor has not reported',
            areaLow: false,
            offline: true,
          ),
          body:
              'No new soil reading for over ${staleAfter.inHours} hours. '
              'Check the device and Wi-Fi.',
          dedupeKey: _dedupe('device_offline', ymd, deviceId),
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
    String? sensorCode,
    String? deviceId,
  }) {
    final band = facts['moisture'] as String? ?? 'missing';
    if (band == 'missing' || band == 'ok') return null;

    final moisture = _fmt(reading.moisturePercent, suffix: '%');
    final rain = (facts['rain_prob_today'] as num?)?.toDouble();

    if (band == 'critical_dry') {
      return NotificationDraft(
        farmId: farmId,
        type: FarmNotificationType.irrigation,
        severity: FarmNotificationSeverity.urgent,
        title: _named(
          sensorCode,
          'Soil is critically dry — water today',
          areaLow: true,
        ),
        body:
            'Soil wetness is critically low${moisture == null ? '' : ' ($moisture)'}. '
            'Do not wait. Water today.',
        dedupeKey: _dedupe('irrigation', ymd, deviceId),
        soilReadingId: reading.id,
      );
    }

    if (band == 'critical_wet') {
      return NotificationDraft(
        farmId: farmId,
        type: FarmNotificationType.irrigation,
        severity: FarmNotificationSeverity.urgent,
        title: _named(
          sensorCode,
          'Soil water is critically high',
          areaLow: false,
          areaWet: true,
        ),
        body:
            'Soil wetness is critically high${moisture == null ? '' : ' ($moisture)'}. '
            'Do not water. Check drainage.',
        dedupeKey: _dedupe('irrigation', ymd, deviceId),
        soilReadingId: reading.id,
      );
    }

    if (band == 'dry' && rain != null && rain >= skipIfRainProbPctGte) {
      return NotificationDraft(
        farmId: farmId,
        type: FarmNotificationType.irrigation,
        severity: FarmNotificationSeverity.info,
        title: _named(
          sensorCode,
          'Rain is likely — wait to irrigate',
          areaLow: true,
        ),
        body:
            'Soil is dry${moisture == null ? '' : ' ($moisture)'} but '
            'rain chance today is ${rain.toStringAsFixed(0)}%. Wait before watering.',
        dedupeKey: _dedupe('irrigation', ymd, deviceId),
        soilReadingId: reading.id,
      );
    }

    if (band == 'dry') {
      return NotificationDraft(
        farmId: farmId,
        type: FarmNotificationType.irrigation,
        severity: FarmNotificationSeverity.urgent,
        title: _named(sensorCode, 'Soil is dry', areaLow: true),
        body:
            'Soil wetness is low${moisture == null ? '' : ' ($moisture)'}. '
            'Irrigate today.',
        dedupeKey: _dedupe('irrigation', ymd, deviceId),
        soilReadingId: reading.id,
      );
    }

    // wet (warn)
    return NotificationDraft(
      farmId: farmId,
      type: FarmNotificationType.irrigation,
      severity: FarmNotificationSeverity.warning,
      title: _named(
        sensorCode,
        'Soil is very wet',
        areaLow: false,
        areaWet: true,
      ),
      body:
          'Soil wetness is high${moisture == null ? '' : ' ($moisture)'}. '
          'Do not irrigate.',
      dedupeKey: _dedupe('irrigation', ymd, deviceId),
      soilReadingId: reading.id,
    );
  }

  NotificationDraft? _nutrients({
    required String farmId,
    required SoilReading reading,
    required Map<String, dynamic> facts,
    required String ymd,
    String? sensorCode,
    String? deviceId,
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
      title: _named(sensorCode, 'Nutrients are low', areaLow: true),
      body: '${_joinList(low)} ${low.length == 1 ? 'is' : 'are'} low. '
          'Consider fertilizer.',
      dedupeKey: _dedupe('nutrient_low', ymd, deviceId),
      soilReadingId: reading.id,
    );
  }

  NotificationDraft? _soilAlert({
    required String farmId,
    required SoilReading reading,
    required Map<String, dynamic> facts,
    required String ymd,
    String? sensorCode,
    String? deviceId,
  }) {
    final issues = <String>[];
    var anyCritical = false;

    anyCritical |= _addBandIssue(
      issues,
      band: facts['ph_band'] as String?,
      label: 'pH',
      value: _fmt(reading.ph),
    );
    anyCritical |= _addBandIssue(
      issues,
      band: facts['temp_band'] as String?,
      label: 'Soil temperature',
      value: _fmt(reading.soilTemperatureC, suffix: '°C'),
    );
    anyCritical |= _addBandIssue(
      issues,
      band: facts['ec_band'] as String?,
      label: 'EC',
      value: _fmt(reading.ec),
    );

    final saltBand = facts['salinity_band'] as String?;
    if (saltBand == 'high' || saltBand == 'critical_high') {
      final salt = _fmt(reading.salinity, suffix: ' ppt');
      if (saltBand == 'critical_high') {
        anyCritical = true;
        issues.add('salinity is critically high${salt == null ? '' : ' ($salt)'}');
      } else {
        issues.add('salinity is high${salt == null ? '' : ' ($salt)'}');
      }
    }

    if (issues.isEmpty) return null;

    return NotificationDraft(
      farmId: farmId,
      type: FarmNotificationType.soilAlert,
      severity: anyCritical
          ? FarmNotificationSeverity.urgent
          : FarmNotificationSeverity.warning,
      title: _named(
        sensorCode,
        anyCritical
            ? 'Urgent: soil needs attention today'
            : 'Soil needs attention',
        areaLow: true,
      ),
      body:
          '${_joinList(issues)}. Check the field before adding water or fertilizer.',
      dedupeKey: _dedupe('soil_alert', ymd, deviceId),
      soilReadingId: reading.id,
    );
  }

  /// Adds an issue for warn/critical bands. Returns true if band was critical.
  bool _addBandIssue(
    List<String> issues, {
    required String? band,
    required String label,
    required String? value,
  }) {
    if (band == null || band == 'ok' || band == 'missing') return false;
    final shown = value == null ? '' : ' ($value)';
    if (band.startsWith('critical_')) {
      final side = band.contains('low') ? 'critically low' : 'critically high';
      issues.add('$label is $side$shown');
      return true;
    }
    if (band == 'low' || band == 'high') {
      issues.add('$label is $band$shown');
    }
    return false;
  }

  /// "Check Sensor (SG-4K91)" when the kit code is known.
  String _checkTitle(String? sensorCode) {
    final code = sensorCode?.trim();
    if (code == null || code.isEmpty) return 'Check the soil sensor';
    return 'Check Sensor ($code)';
  }

  /// Sticker wording when [sensorCode] is set. Otherwise the original title.
  String _named(
    String? sensorCode,
    String plain, {
    required bool areaLow,
    bool areaWet = false,
    bool offline = false,
  }) {
    final code = sensorCode?.trim();
    if (code == null || code.isEmpty) return plain;
    if (offline) return 'Sensor ($code) has not reported';
    if (areaLow) return 'Sensor ($code) area is low';
    if (areaWet) return 'Sensor ($code) area is very wet';
    return 'Sensor ($code)';
  }

  /// One alert per kit per Manila day. Without a device, the farm-wide key stays.
  String _dedupe(String type, String ymd, String? deviceId) {
    final id = deviceId?.trim();
    if (id == null || id.isEmpty) return '$type:$ymd';
    return '$type:$id:$ymd';
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
