/// Data types for one farm alert row stored in Supabase `farm_notifications`.
///
/// Shared by the notification engine (classifies soil + weather) and the
/// pushed inbox page (bell → slide from right). Not a widget file.
library;

/// Alert kinds the engine may insert. Keep in sync with the SQL check constraint.
enum FarmNotificationType {
  irrigation,
  nutrientLow,
  soilAlert,
  sensorError,
  deviceOffline,
  phaseChange;

  String get wireName => switch (this) {
    irrigation => 'irrigation',
    nutrientLow => 'nutrient_low',
    soilAlert => 'soil_alert',
    sensorError => 'sensor_error',
    deviceOffline => 'device_offline',
    phaseChange => 'phase_change',
  };

  /// Short farmer-facing label for chips.
  String get farmerLabel => switch (this) {
    irrigation => 'Irrigation',
    nutrientLow => 'Nutrients',
    soilAlert => 'Soil',
    sensorError => 'Sensor',
    deviceOffline => 'Device',
    phaseChange => 'Phase',
  };

  /// Shell tab that owns this alert (0 Home, 2 Crops). Bell shows all.
  int? get shellTabIndex => switch (this) {
    irrigation || soilAlert || sensorError || deviceOffline => 0,
    nutrientLow || phaseChange => 2,
  };

  /// Types whose red dot lives on [tabIndex].
  static Set<FarmNotificationType> typesForTab(int tabIndex) {
    return {
      for (final t in values)
        if (t.shellTabIndex == tabIndex) t,
    };
  }

  static FarmNotificationType parse(String raw) {
    return switch (raw) {
      'irrigation' => irrigation,
      'nutrient_low' => nutrientLow,
      'soil_alert' => soilAlert,
      'sensor_error' => sensorError,
      'device_offline' => deviceOffline,
      'phase_change' => phaseChange,
      _ => throw FormatException('Unknown farm_notifications.type: $raw'),
    };
  }
}

/// How urgent the farmer should treat the alert.
enum FarmNotificationSeverity {
  info,
  warning,
  urgent;

  String get wireName => name;

  static FarmNotificationSeverity parse(String raw) {
    return switch (raw) {
      'info' => info,
      'warning' => warning,
      'urgent' => urgent,
      _ => throw FormatException('Unknown farm_notifications.severity: $raw'),
    };
  }
}

/// Insert payload before it has a database id.
class NotificationDraft {
  const NotificationDraft({
    required this.farmId,
    required this.type,
    required this.severity,
    required this.title,
    required this.body,
    required this.dedupeKey,
    this.soilReadingId,
  });

  final String farmId;
  final FarmNotificationType type;
  final FarmNotificationSeverity severity;
  final String title;
  final String body;
  final String dedupeKey;
  final String? soilReadingId;

  /// Column names match `farm_notifications`.
  Map<String, dynamic> toInsertJson() {
    return {
      'farm_id': farmId,
      'type': type.wireName,
      'severity': severity.wireName,
      'title': title,
      'body': body,
      'dedupe_key': dedupeKey,
      'soil_reading_id': ?soilReadingId,
    };
  }
}

/// One persisted farm alert.
class FarmNotification {
  const FarmNotification({
    required this.id,
    required this.farmId,
    required this.type,
    required this.severity,
    required this.title,
    required this.body,
    required this.dedupeKey,
    required this.createdAt,
    this.soilReadingId,
    this.readAt,
  });

  final String id;
  final String farmId;
  final FarmNotificationType type;
  final FarmNotificationSeverity severity;
  final String title;
  final String body;
  final String dedupeKey;
  final DateTime createdAt;
  final String? soilReadingId;
  final DateTime? readAt;

  bool get isUnread => readAt == null;

  /// Used for optimistic mark-read in the inbox; rollback restores the old row.
  FarmNotification copyWith({DateTime? readAt}) {
    return FarmNotification(
      id: id,
      farmId: farmId,
      type: type,
      severity: severity,
      title: title,
      body: body,
      dedupeKey: dedupeKey,
      createdAt: createdAt,
      soilReadingId: soilReadingId,
      readAt: readAt ?? this.readAt,
    );
  }

  factory FarmNotification.fromJson(Map<String, dynamic> json) {
    return FarmNotification(
      id: json['id'] as String,
      farmId: json['farm_id'] as String,
      type: FarmNotificationType.parse(json['type'] as String),
      severity: FarmNotificationSeverity.parse(json['severity'] as String),
      title: json['title'] as String,
      body: json['body'] as String,
      dedupeKey: json['dedupe_key'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      soilReadingId: json['soil_reading_id'] as String?,
      readAt: json['read_at'] == null
          ? null
          : DateTime.parse(json['read_at'] as String),
    );
  }
}
