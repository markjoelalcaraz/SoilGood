/// Crop-aware soil band labels (ok / warn / critical) for Home AI + alerts.
///
/// Uses catalog min/max when an active planting exists, plus phase overlays and
/// global extreme floors. Falls back to insights.json universal bands when no
/// crop range is supplied. NPK stays universal low-only (caller still uses
/// InsightsConfig for N/P/K).
library;

import '../../features/crops/data/crop_catalog.dart';

/// Global sensor floors (any crop / no crop).
const kMoistureCriticalDryLt = 15.0;
const kMoistureCriticalWetGt = 95.0;
const kTempCriticalLowLt = 10.0;
const kTempCriticalHighGt = 42.0;

/// Universal defaults when no crop (mirror insights.json).
const kUniversalMoistureDryLt = 30.0;
const kUniversalMoistureWetGt = 85.0;
const kUniversalTempLowLt = 15.0;
const kUniversalTempHighGt = 35.0;
const kUniversalPhLowLt = 5.5;
const kUniversalPhHighGt = 7.5;
const kUniversalEcLowLt = 0.2;
const kUniversalEcHighGt = 2.0;
const kUniversalSalinityHighGt = 4.0;

/// Phase ids that tighten moisture (flowering / reproductive stress windows).
const kTightenMoisturePhaseIds = {
  'reproductive',
  'flowering_fruiting',
  'flowering_pegging',
  'bulb_swell',
  'shooting',
  'tuber_init',
  'fruit_fill',
  'grain_fill',
};

/// Phase ids that intentionally dry down (soften dry, raise wet sensitivity).
const kDryDownPhaseIds = {
  'dry_down',
  'ripening',
  'harvest',
  'heading',
  'pod_fill',
};

/// Phase ids where heat outside band escalates faster.
const kHeatCriticalPhaseIds = {
  'reproductive',
  'flowering_fruiting',
  'flowering_pegging',
};

/// Catalog slice used for classification (not full CropCatalogEntry).
class CropBandRanges {
  const CropBandRanges({
    this.moistureMin,
    this.moistureMax,
    this.temperatureMinC,
    this.temperatureMaxC,
    this.phMin,
    this.phMax,
    this.ecMin,
    this.ecMax,
    this.salinityMax,
    this.phaseId,
    this.hydroClass,
  });

  final double? moistureMin;
  final double? moistureMax;
  final double? temperatureMinC;
  final double? temperatureMaxC;
  final double? phMin;
  final double? phMax;
  final double? ecMin;
  final double? ecMax;
  final double? salinityMax;
  final String? phaseId;
  final String? hydroClass;

  /// Builds from a catalog crop + optional current phase id.
  factory CropBandRanges.fromCrop(
    CropCatalogEntry crop, {
    String? phaseId,
  }) {
    final meta = crop.rangeMeta;
    final hydro = meta?['hydro_class'] as String?;
    return CropBandRanges(
      moistureMin: crop.moistureMin,
      moistureMax: crop.moistureMax,
      temperatureMinC: crop.temperatureMinC,
      temperatureMaxC: crop.temperatureMaxC,
      phMin: crop.phMin,
      phMax: crop.phMax,
      ecMin: crop.ecMin,
      ecMax: crop.ecMax,
      salinityMax: crop.salinityMax,
      phaseId: phaseId,
      hydroClass: hydro,
    );
  }

  /// Compact identity for Home story fingerprint regen.
  String fingerprintToken() {
    String n(double? v) => v == null ? 'x' : v.toStringAsFixed(1);
    return [
      n(moistureMin),
      n(moistureMax),
      n(temperatureMinC),
      n(temperatureMaxC),
      n(phMin),
      n(phMax),
      n(ecMax),
      n(salinityMax),
      phaseId ?? 'none',
    ].join(',');
  }
}

/// Moisture labels: critical_dry | dry | ok | wet | critical_wet | missing.
String classifyMoistureBand({
  required double? value,
  CropBandRanges? crop,
}) {
  if (value == null) return 'missing';
  if (value < kMoistureCriticalDryLt) return 'critical_dry';
  // Rice (class A) can sit near saturation; do not force critical_wet at 95.
  final isPaddy = crop?.hydroClass == 'A';
  if (!isPaddy && value > kMoistureCriticalWetGt) return 'critical_wet';

  final min = crop?.moistureMin ?? kUniversalMoistureDryLt;
  final max = crop?.moistureMax ?? kUniversalMoistureWetGt;
  final phase = crop?.phaseId;
  final tighten = phase != null && kTightenMoisturePhaseIds.contains(phase);
  final dryDown = phase != null && kDryDownPhaseIds.contains(phase);
  var frac = tighten ? 0.10 : 0.15;
  if (dryDown) {
    // Soften dry warn, raise wet sensitivity.
    return _spanBand(
      value: value,
      min: min,
      max: max,
      lowFrac: 0.22,
      highFrac: 0.08,
      criticalLow: 'critical_dry',
      warnLow: 'dry',
      criticalHigh: 'critical_wet',
      warnHigh: 'wet',
    );
  }
  return _spanBand(
    value: value,
    min: min,
    max: max,
    lowFrac: frac,
    highFrac: frac,
    criticalLow: 'critical_dry',
    warnLow: 'dry',
    criticalHigh: 'critical_wet',
    warnHigh: 'wet',
  );
}

/// Temp labels: critical_low | low | ok | high | critical_high | missing.
String classifyTempBand({
  required double? value,
  CropBandRanges? crop,
}) {
  if (value == null) return 'missing';
  if (value < kTempCriticalLowLt) return 'critical_low';
  if (value > kTempCriticalHighGt) return 'critical_high';

  final min = crop?.temperatureMinC ?? kUniversalTempLowLt;
  final max = crop?.temperatureMaxC ?? kUniversalTempHighGt;
  final phase = crop?.phaseId;
  final heatPhase =
      phase != null && kHeatCriticalPhaseIds.contains(phase);

  // Fixed °C slack: warn within 3°C outside band; critical beyond (or 2°C in heat phase).
  final warnSlack = heatPhase ? 2.0 : 3.0;
  if (value < min) {
    if (value < min - warnSlack) return 'critical_low';
    return 'low';
  }
  if (value > max) {
    if (value > max + warnSlack) return 'critical_high';
    return 'high';
  }
  return 'ok';
}

/// pH: critical_low | low | ok | high | critical_high | missing.
String classifyPhBand({
  required double? value,
  CropBandRanges? crop,
}) {
  if (value == null) return 'missing';
  final min = crop?.phMin ?? kUniversalPhLowLt;
  final max = crop?.phMax ?? kUniversalPhHighGt;
  final s = (max - min).abs();
  final frac = s < 0.1 ? 0.3 : 0.15;
  return _spanBand(
    value: value,
    min: min,
    max: max,
    lowFrac: frac,
    highFrac: frac,
    criticalLow: 'critical_low',
    warnLow: 'low',
    criticalHigh: 'critical_high',
    warnHigh: 'high',
  );
}

/// EC: critical_low | low | ok | high | critical_high | missing.
String classifyEcBand({
  required double? value,
  CropBandRanges? crop,
}) {
  if (value == null) return 'missing';
  final min = crop?.ecMin ?? kUniversalEcLowLt;
  final max = crop?.ecMax ?? kUniversalEcHighGt;
  final s = (max - min).abs();
  final frac = s < 0.05 ? 0.25 : 0.15;
  return _spanBand(
    value: value,
    min: min,
    max: max,
    lowFrac: frac,
    highFrac: frac,
    criticalLow: 'critical_low',
    warnLow: 'low',
    criticalHigh: 'critical_high',
    warnHigh: 'high',
  );
}

/// Salinity high-only with optional crop max: ok | high | critical_high | missing.
String classifySalinityBand({
  required double? value,
  CropBandRanges? crop,
}) {
  if (value == null) return 'missing';
  final max = crop?.salinityMax ?? kUniversalSalinityHighGt;
  if (value <= max) return 'ok';
  // Far above crop/universal max → critical.
  if (value > max * 1.35) return 'critical_high';
  return 'high';
}

/// True when a band string is a critical_* label.
bool isCriticalBand(String? band) {
  if (band == null) return false;
  return band.startsWith('critical_');
}

String _spanBand({
  required double value,
  required double min,
  required double max,
  required double lowFrac,
  required double highFrac,
  required String criticalLow,
  required String warnLow,
  required String criticalHigh,
  required String warnHigh,
}) {
  final span = (max - min).abs();
  final lowSlack = span * lowFrac;
  final highSlack = span * highFrac;
  if (value >= min && value <= max) return 'ok';
  if (value < min) {
    if (value < min - lowSlack) return criticalLow;
    return warnLow;
  }
  if (value > max + highSlack) return criticalHigh;
  return warnHigh;
}
