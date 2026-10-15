/// Curated BSWM/PhilRice soil series for optional farm profile + crop match.
///
/// Typical texture is catalog metadata for UI hints only. Scoring uses
/// crop_series_fit when a curated series is set; otherwise texture fit applies.
/// Research: docs/context/SOIL_SERIES_CROP_FIT.md.
library;

import 'soil_texture.dart';

/// Optional soil series pick. [other] falls back to texture scoring.
enum SoilSeries {
  bantog(
    'bantog',
    'Bantog',
    SoilTexture.clayLoam,
    'Sticky clay loam — drains slowly; cracks when dry',
  ),
  maligaya(
    'maligaya',
    'Maligaya',
    SoilTexture.clay,
    'Heavy clay — very slow drainage',
  ),
  bigaa(
    'bigaa',
    'Bigaa',
    SoilTexture.clay,
    'Firm clay — hardens when dry',
  ),
  sanManuel(
    'san_manuel',
    'San Manuel',
    SoilTexture.loam,
    'Friable loam — often good for many crops',
  ),
  quingua(
    'quingua',
    'Quingua',
    SoilTexture.loam,
    'Medium loam — works for rice and cash crops',
  ),
  umingan(
    'umingan',
    'Umingan',
    SoilTexture.sandyLoam,
    'Sandy loam with stones underneath — flood and drought risk',
  ),
  sanFernando(
    'san_fernando',
    'San Fernando',
    SoilTexture.clayLoam,
    'Clay loam — strong for irrigated rice and corn',
  ),
  angeles(
    'angeles',
    'Angeles',
    SoilTexture.sandy,
    'Sand — drains fast; lower fertility',
  ),
  obando(
    'obando',
    'Obando',
    SoilTexture.sandyLoam,
    'Sandy loam — good for root crops',
  ),
  other(
    'other',
    'Others',
    SoilTexture.unknown,
    'Not in the list — texture is used for match score',
  );

  const SoilSeries(this.wire, this.label, this.typicalTexture, this.hint);

  final String wire;
  final String label;

  /// Catalog typical feel for UI hint — does not overwrite farms.soil_texture.
  final SoilTexture typicalTexture;

  final String hint;

  /// True when this series has a crop-fit table (not Other).
  bool get countsForMatch => this != SoilSeries.other;

  static SoilSeries? fromWire(String? wire) {
    if (wire == null || wire.trim().isEmpty) return null;
    for (final s in SoilSeries.values) {
      if (s.wire == wire) return s;
    }
    return null;
  }

  /// Curated picks shown in onboarding (includes Other).
  static List<SoilSeries> get onboardingChoices => SoilSeries.values;
}
