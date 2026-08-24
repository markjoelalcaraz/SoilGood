/// Reference crop row from `public.crops` (ideal ranges + cultivation phases).
///
/// Used by the Crops tab for local match scores and the in-tab timeline.
/// Not a UI file — presentation maps these into match cards and phase chips.
library;

/// One named stretch of the growing cycle (days are consecutive, not overlapping).
class CropPhase {
  const CropPhase({
    required this.id,
    required this.label,
    required this.days,
  });

  final String id;
  final String label;
  final int days;

  factory CropPhase.fromJson(Map<String, dynamic> json) {
    return CropPhase(
      id: json['id'] as String? ?? 'phase',
      label: json['label'] as String? ?? 'Phase',
      days: (json['days'] as num?)?.toInt() ?? 0,
    );
  }
}

/// One catalog crop with optional ideal soil ranges.
class CropCatalogEntry {
  const CropCatalogEntry({
    required this.id,
    required this.name,
    this.scientificName,
    this.daysToMaturity,
    this.phases = const [],
    this.moistureMin,
    this.moistureMax,
    this.phMin,
    this.phMax,
    this.temperatureMinC,
    this.temperatureMaxC,
    this.ecMin,
    this.ecMax,
    this.nitrogenMin,
    this.nitrogenMax,
    this.phosphorusMin,
    this.phosphorusMax,
    this.potassiumMin,
    this.potassiumMax,
    this.salinityMin,
    this.salinityMax,
    this.growingSeason,
    this.notes,
    this.rangeMeta,
  });

  final String id;
  final String name;
  final String? scientificName;
  final int? daysToMaturity;
  final List<CropPhase> phases;
  final double? moistureMin;
  final double? moistureMax;
  final double? phMin;
  final double? phMax;
  final double? temperatureMinC;
  final double? temperatureMaxC;
  final double? ecMin;
  final double? ecMax;
  final double? nitrogenMin;
  final double? nitrogenMax;
  final double? phosphorusMin;
  final double? phosphorusMax;
  final double? potassiumMin;
  final double? potassiumMax;
  final double? salinityMin;
  final double? salinityMax;
  final String? growingSeason;
  final String? notes;

  /// Honesty labels: moisture_basis, ec_basis, hydro_class, etc.
  final Map<String, dynamic>? rangeMeta;

  factory CropCatalogEntry.fromJson(Map<String, dynamic> json) {
    final phasesRaw = json['phases'];
    final phases = <CropPhase>[];
    if (phasesRaw is List) {
      for (final item in phasesRaw) {
        if (item is Map) {
          phases.add(CropPhase.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    return CropCatalogEntry(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Crop',
      scientificName: json['scientific_name'] as String?,
      daysToMaturity: (json['days_to_maturity'] as num?)?.toInt(),
      phases: phases,
      moistureMin: (json['moisture_min'] as num?)?.toDouble(),
      moistureMax: (json['moisture_max'] as num?)?.toDouble(),
      phMin: (json['ph_min'] as num?)?.toDouble(),
      phMax: (json['ph_max'] as num?)?.toDouble(),
      temperatureMinC: (json['temperature_min_c'] as num?)?.toDouble(),
      temperatureMaxC: (json['temperature_max_c'] as num?)?.toDouble(),
      ecMin: (json['ec_min'] as num?)?.toDouble(),
      ecMax: (json['ec_max'] as num?)?.toDouble(),
      nitrogenMin: (json['nitrogen_min'] as num?)?.toDouble(),
      nitrogenMax: (json['nitrogen_max'] as num?)?.toDouble(),
      phosphorusMin: (json['phosphorus_min'] as num?)?.toDouble(),
      phosphorusMax: (json['phosphorus_max'] as num?)?.toDouble(),
      potassiumMin: (json['potassium_min'] as num?)?.toDouble(),
      potassiumMax: (json['potassium_max'] as num?)?.toDouble(),
      salinityMin: (json['salinity_min'] as num?)?.toDouble(),
      salinityMax: (json['salinity_max'] as num?)?.toDouble(),
      growingSeason: json['growing_season'] as String?,
      notes: json['notes'] as String?,
      rangeMeta: json['range_meta'] is Map
          ? Map<String, dynamic>.from(json['range_meta'] as Map)
          : null,
    );
  }
}
