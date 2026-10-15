/// Per-series crop fit tables for local crop match scoring.
///
/// Source: docs/context/SOIL_SERIES_CROP_FIT.md (PhilRice PSIS group proxies).
/// When a curated series is set, this replaces texture fit in crop_match.
library;

import '../../../core/soil/soil_series.dart';
import 'crop_texture_fit.dart';

/// Lookup series fit for one catalog crop by display name.
CropTextureFitLevel seriesFitForCrop({
  required String cropName,
  required SoilSeries? farmSeries,
}) {
  if (farmSeries == null || !farmSeries.countsForMatch) {
    return CropTextureFitLevel.skip;
  }

  final table = _fitBySeries[farmSeries];
  if (table == null) return CropTextureFitLevel.skip;

  if (table.preferred.contains(cropName)) {
    return CropTextureFitLevel.preferred;
  }
  if (table.acceptable.contains(cropName)) {
    return CropTextureFitLevel.acceptable;
  }
  if (table.caution.contains(cropName)) {
    return CropTextureFitLevel.caution;
  }
  return CropTextureFitLevel.caution;
}

/// Short reason fragment when series was used in the score.
String seriesReasonFragment({
  required String cropName,
  required SoilSeries farmSeries,
  required CropTextureFitLevel level,
}) {
  return switch (level) {
    CropTextureFitLevel.preferred =>
      '${farmSeries.label} series fits $cropName well',
    CropTextureFitLevel.acceptable =>
      '${farmSeries.label} series is acceptable for $cropName',
    CropTextureFitLevel.caution =>
      '${farmSeries.label} series is a poor match for $cropName',
    CropTextureFitLevel.skip => '',
  };
}

class _SeriesCropTable {
  const _SeriesCropTable({
    required this.preferred,
    this.acceptable = const {},
    required this.caution,
  });

  final Set<String> preferred;
  final Set<String> acceptable;
  final Set<String> caution;
}

const _rice = {'Rice (Palay)'};
const _corn = {'Corn (Mais)'};
const _veg = {
  'Tomato',
  'Eggplant',
  'Ampalaya',
  'Sitaw',
  'Okra',
  'Cabbage',
  'Chili',
  'Cucumber',
  'Squash',
};
const _allium = {'Onion', 'Garlic'};
const _root = {'Cassava', 'Sweet potato', 'Peanut'};
const _banana = {'Banana Saba'};

Set<String> _union(Iterable<Set<String>> parts) =>
    parts.fold(<String>{}, (a, b) => a..addAll(b));

/// Remaining catalog crops not in [keep] → caution.
Set<String> _cautionExcept(Set<String> keep) =>
    _union([_rice, _corn, _veg, _allium, _root, _banana]).difference(keep);

final _fitBySeries = <SoilSeries, _SeriesCropTable>{
  SoilSeries.bantog: _SeriesCropTable(
    preferred: _union([_rice, _root]),
    acceptable: _union([_corn, _veg, _allium, _banana]),
    caution: const {},
  ),
  SoilSeries.maligaya: _SeriesCropTable(
    preferred: _rice,
    acceptable: _root,
    caution: _cautionExcept(_union([_rice, _root])),
  ),
  SoilSeries.bigaa: _SeriesCropTable(
    preferred: _rice,
    acceptable: _veg,
    caution: _cautionExcept(_union([_rice, _veg])),
  ),
  SoilSeries.sanManuel: _SeriesCropTable(
    preferred: _union([_rice, _corn, _veg, _allium, _root, _banana]),
    caution: const {},
  ),
  SoilSeries.quingua: _SeriesCropTable(
    preferred: _union([_rice, _corn, _veg, _root]),
    acceptable: _union([_allium, _banana]),
    caution: const {},
  ),
  SoilSeries.umingan: _SeriesCropTable(
    preferred: const {},
    acceptable: _union([_rice, _corn, _veg, _allium, _banana]),
    caution: _root,
  ),
  SoilSeries.sanFernando: _SeriesCropTable(
    preferred: _union([_rice, _corn]),
    acceptable: _union([_veg, _allium, _root, _banana]),
    caution: const {},
  ),
  SoilSeries.angeles: _SeriesCropTable(
    preferred: const {},
    acceptable: _root,
    caution: _cautionExcept(_root),
  ),
  SoilSeries.obando: _SeriesCropTable(
    preferred: _root,
    acceptable: _union([_rice, _corn, _veg, _allium, _banana]),
    caution: const {},
  ),
};
