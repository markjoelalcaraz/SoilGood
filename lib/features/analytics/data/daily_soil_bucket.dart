/// One Asia/Manila calendar day of aggregated 8-in-1 soil stats.
///
/// Produced by RPC `analytics_soil_daily`. Analytics charts and period captions
/// use these buckets — not live Home readings and not every 15-minute row.
library;

/// Daily avg/min/max for all 8 soil parameters plus how many raw rows that day.
class DailySoilBucket {
  const DailySoilBucket({
    required this.bucketDate,
    required this.readingCount,
    this.avgMoisture,
    this.minMoisture,
    this.maxMoisture,
    this.avgPh,
    this.minPh,
    this.maxPh,
    this.avgTemp,
    this.minTemp,
    this.maxTemp,
    this.avgEc,
    this.minEc,
    this.maxEc,
    this.avgSalinity,
    this.minSalinity,
    this.maxSalinity,
    this.avgNitrogen,
    this.minNitrogen,
    this.maxNitrogen,
    this.avgPhosphorus,
    this.minPhosphorus,
    this.maxPhosphorus,
    this.avgPotassium,
    this.minPotassium,
    this.maxPotassium,
  });

  /// Calendar date in Asia/Manila (time is midnight local, unused).
  final DateTime bucketDate;
  final int readingCount;

  final double? avgMoisture;
  final double? minMoisture;
  final double? maxMoisture;
  final double? avgPh;
  final double? minPh;
  final double? maxPh;
  final double? avgTemp;
  final double? minTemp;
  final double? maxTemp;
  final double? avgEc;
  final double? minEc;
  final double? maxEc;
  final double? avgSalinity;
  final double? minSalinity;
  final double? maxSalinity;
  final double? avgNitrogen;
  final double? minNitrogen;
  final double? maxNitrogen;
  final double? avgPhosphorus;
  final double? minPhosphorus;
  final double? maxPhosphorus;
  final double? avgPotassium;
  final double? minPotassium;
  final double? maxPotassium;

  factory DailySoilBucket.fromJson(Map<String, dynamic> json) {
    return DailySoilBucket(
      bucketDate: _parseDate(json['bucket_date']),
      readingCount: (json['reading_count'] as num?)?.toInt() ?? 0,
      avgMoisture: _d(json['avg_moisture']),
      minMoisture: _d(json['min_moisture']),
      maxMoisture: _d(json['max_moisture']),
      avgPh: _d(json['avg_ph']),
      minPh: _d(json['min_ph']),
      maxPh: _d(json['max_ph']),
      avgTemp: _d(json['avg_temp']),
      minTemp: _d(json['min_temp']),
      maxTemp: _d(json['max_temp']),
      avgEc: _d(json['avg_ec']),
      minEc: _d(json['min_ec']),
      maxEc: _d(json['max_ec']),
      avgSalinity: _d(json['avg_salinity']),
      minSalinity: _d(json['min_salinity']),
      maxSalinity: _d(json['max_salinity']),
      avgNitrogen: _d(json['avg_nitrogen']),
      minNitrogen: _d(json['min_nitrogen']),
      maxNitrogen: _d(json['max_nitrogen']),
      avgPhosphorus: _d(json['avg_phosphorus']),
      minPhosphorus: _d(json['min_phosphorus']),
      maxPhosphorus: _d(json['max_phosphorus']),
      avgPotassium: _d(json['avg_potassium']),
      minPotassium: _d(json['min_potassium']),
      maxPotassium: _d(json['max_potassium']),
    );
  }

  static double? _d(Object? v) => (v as num?)?.toDouble();

  /// RPC date is `YYYY-MM-DD` (Manila calendar), not a timestamptz.
  static DateTime _parseDate(Object? raw) {
    if (raw is DateTime) {
      return DateTime(raw.year, raw.month, raw.day);
    }
    final text = raw.toString();
    final parts = text.split('-');
    if (parts.length < 3) {
      throw FormatException('Invalid bucket_date: $raw');
    }
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2].substring(0, 2)),
    );
  }
}

/// Which 8-in-1 series the Analytics chart is showing.
enum SoilMetric {
  moisture,
  ph,
  temperature,
  ec,
  salinity,
  nitrogen,
  phosphorus,
  potassium,
}

extension SoilMetricChart on SoilMetric {
  String get label => switch (this) {
    SoilMetric.moisture => 'Moisture',
    SoilMetric.ph => 'pH',
    SoilMetric.temperature => 'Temp',
    SoilMetric.ec => 'EC',
    SoilMetric.salinity => 'Salinity',
    SoilMetric.nitrogen => 'N',
    SoilMetric.phosphorus => 'P',
    SoilMetric.potassium => 'K',
  };

  String get unit => switch (this) {
    SoilMetric.moisture => '%',
    SoilMetric.ph => '',
    SoilMetric.temperature => '°C',
    SoilMetric.ec => 'dS/m',
    SoilMetric.salinity => 'ppt',
    SoilMetric.nitrogen => 'ppm',
    SoilMetric.phosphorus => 'ppm',
    SoilMetric.potassium => 'ppm',
  };

  double? avgOf(DailySoilBucket b) => switch (this) {
    SoilMetric.moisture => b.avgMoisture,
    SoilMetric.ph => b.avgPh,
    SoilMetric.temperature => b.avgTemp,
    SoilMetric.ec => b.avgEc,
    SoilMetric.salinity => b.avgSalinity,
    SoilMetric.nitrogen => b.avgNitrogen,
    SoilMetric.phosphorus => b.avgPhosphorus,
    SoilMetric.potassium => b.avgPotassium,
  };

  double? minOf(DailySoilBucket b) => switch (this) {
    SoilMetric.moisture => b.minMoisture,
    SoilMetric.ph => b.minPh,
    SoilMetric.temperature => b.minTemp,
    SoilMetric.ec => b.minEc,
    SoilMetric.salinity => b.minSalinity,
    SoilMetric.nitrogen => b.minNitrogen,
    SoilMetric.phosphorus => b.minPhosphorus,
    SoilMetric.potassium => b.minPotassium,
  };

  double? maxOf(DailySoilBucket b) => switch (this) {
    SoilMetric.moisture => b.maxMoisture,
    SoilMetric.ph => b.maxPh,
    SoilMetric.temperature => b.maxTemp,
    SoilMetric.ec => b.maxEc,
    SoilMetric.salinity => b.maxSalinity,
    SoilMetric.nitrogen => b.maxNitrogen,
    SoilMetric.phosphorus => b.maxPhosphorus,
    SoilMetric.potassium => b.maxPotassium,
  };
}
