/// Data model for one soil sensor sample used by the Home dashboard.
///
/// Maps fields from the Supabase soil_readings table (moisture, pH, temp, EC,
/// NPK, validation). Not a UI file — Home widgets display instances of this.
library;

/// One timestamped soil sensor sample from Supabase.
class SoilReading {
  const SoilReading({
    required this.id,
    required this.recordedAt,
    this.moisturePercent,
    this.ph,
    this.soilTemperatureC,
    this.ec,
    this.nitrogen,
    this.phosphorus,
    this.potassium,
    this.validationStatus = 'ok',
    this.validationMessage,
  });

  final String id;
  final DateTime recordedAt;
  final double? moisturePercent;
  final double? ph;
  final double? soilTemperatureC;
  final double? ec;
  final double? nitrogen;
  final double? phosphorus;
  final double? potassium;
  final String validationStatus;
  final String? validationMessage;

  factory SoilReading.fromJson(Map<String, dynamic> json) {
    return SoilReading(
      id: json['id'] as String,
      recordedAt: DateTime.parse(json['recorded_at'] as String),
      moisturePercent: (json['moisture_percent'] as num?)?.toDouble(),
      ph: (json['ph'] as num?)?.toDouble(),
      soilTemperatureC: (json['soil_temperature_c'] as num?)?.toDouble(),
      ec: (json['ec'] as num?)?.toDouble(),
      nitrogen: (json['nitrogen'] as num?)?.toDouble(),
      phosphorus: (json['phosphorus'] as num?)?.toDouble(),
      potassium: (json['potassium'] as num?)?.toDouble(),
      validationStatus: (json['validation_status'] as String?) ?? 'ok',
      validationMessage: json['validation_message'] as String?,
    );
  }
}
