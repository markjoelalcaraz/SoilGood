/// Farmer-selected soil texture classes for crop suitability (not sensor-derived).
///
/// Stored on `farms.soil_texture` as wire strings. Used by onboarding and the
/// Crops tab match score as a third pillar beside 8-in-1 chemistry + weather.
library;

/// USDA-style texture feel classes (PhilRice Simplified Keys language).
enum SoilTexture {
  sandy('sandy', 'Sandy', 'Gritty — dries quickly'),
  sandyLoam('sandy_loam', 'Sandy loam', 'A bit gritty — holds some water'),
  loam('loam', 'Loam', 'Balanced — not too sandy or muddy'),
  clayLoam('clay_loam', 'Clay loam', 'A bit sticky — with a little grit'),
  clay('clay', 'Clay', 'Sticky — drains slowly'),
  unknown('unknown', 'Not sure', 'No texture weight in crop match');

  const SoilTexture(this.wire, this.label, this.feelHint);

  /// Value stored in Supabase `farms.soil_texture`.
  final String wire;

  /// Short farmer-facing label.
  final String label;

  /// One-line feel hint for onboarding pickers.
  final String feelHint;

  /// Parses DB / JSON wire value; null when column unset.
  static SoilTexture? fromWire(String? wire) {
    if (wire == null || wire.trim().isEmpty) return null;
    for (final t in SoilTexture.values) {
      if (t.wire == wire) return t;
    }
    return null;
  }

  /// Textures selectable during onboarding (includes not sure).
  static List<SoilTexture> get onboardingChoices => SoilTexture.values;

  /// True when texture should participate in crop match scoring.
  bool get countsForMatch => this != SoilTexture.unknown;
}
