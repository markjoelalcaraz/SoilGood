/// Client-side mirrors of `ingest_soil_reading` range checks.
///
/// Must stay aligned with [`docs/context/supabase_esp32_ingest.sql`](../../../docs/context/supabase_esp32_ingest.sql).
/// Used so unit tests (TC_SOIL_001 / TC_SOIL_002) and any future pre-check
/// reject out-of-range values the same way the RPC does — no silent accept.
library;

/// Result of validating one ingest payload against SQL range rules.
class SoilIngestValidation {
  const SoilIngestValidation._({this.error});

  /// Null when every provided field is in range (or null / omitted).
  final String? error;

  bool get isValid => error == null;

  static const SoilIngestValidation ok = SoilIngestValidation._();

  static SoilIngestValidation fail(String message) =>
      SoilIngestValidation._(error: message);
}

/// Validates optional 8-in-1 fields against the ingest RPC limits.
///
/// Null fields are allowed (same as SQL `is not null` guards). First failure
/// wins so messages match the RPC raise order: moisture → pH → salinity.
SoilIngestValidation validateSoilIngestRanges({
  double? moisturePercent,
  double? ph,
  double? salinity,
}) {
  if (moisturePercent != null &&
      (moisturePercent < 0 || moisturePercent > 100)) {
    return SoilIngestValidation.fail('moisture out of range');
  }
  if (ph != null && (ph < 0 || ph > 14)) {
    return SoilIngestValidation.fail('ph out of range');
  }
  // THE01888S salinity band matches ingest SQL (not ppt-only 0–50).
  if (salinity != null && (salinity < 0 || salinity > 20000)) {
    return SoilIngestValidation.fail('salinity out of range');
  }
  return SoilIngestValidation.ok;
}
