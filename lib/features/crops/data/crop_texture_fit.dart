/// Per-crop soil texture fit tables for local crop match scoring.
///
/// Source of truth for lists: docs/context/SOIL_TEXTURE_CROP_FIT.md (DA/ATI/PhilRice).
/// Maps catalog crop **name** to preferred / acceptable / caution texture classes.
library;

import '../../../core/soil/soil_texture.dart';

/// How a farm texture relates to one catalog crop.
enum CropTextureFitLevel { preferred, acceptable, caution, skip }

/// Lookup texture fit for one catalog crop by its display name.
CropTextureFitLevel textureFitForCrop({
  required String cropName,
  required SoilTexture? farmTexture,
}) {
  if (farmTexture == null || !farmTexture.countsForMatch) {
    return CropTextureFitLevel.skip;
  }

  final table = _fitByCropName[cropName];
  if (table == null) return CropTextureFitLevel.skip;

  if (table.preferred.contains(farmTexture)) {
    return CropTextureFitLevel.preferred;
  }
  if (table.acceptable.contains(farmTexture)) {
    return CropTextureFitLevel.acceptable;
  }
  if (table.caution.contains(farmTexture)) {
    return CropTextureFitLevel.caution;
  }
  return CropTextureFitLevel.caution;
}

/// Maps fit level to the binary check used in [crop_match.dart].
bool? textureInRange(CropTextureFitLevel level) {
  return switch (level) {
    CropTextureFitLevel.preferred => true,
    CropTextureFitLevel.acceptable => true,
    CropTextureFitLevel.caution => false,
    CropTextureFitLevel.skip => null,
  };
}

/// Short reason fragment for match cards when texture was considered.
String textureReasonFragment({
  required String cropName,
  required SoilTexture farmTexture,
  required CropTextureFitLevel level,
}) {
  return switch (level) {
    CropTextureFitLevel.preferred =>
      '${farmTexture.label} soil fits $cropName well',
    CropTextureFitLevel.acceptable =>
      '${farmTexture.label} soil is acceptable for $cropName',
    CropTextureFitLevel.caution =>
      '${farmTexture.label} soil is a poor match for $cropName',
    CropTextureFitLevel.skip => '',
  };
}

class _CropTextureTable {
  const _CropTextureTable({
    required this.preferred,
    this.acceptable = const {},
    required this.caution,
  });

  final Set<SoilTexture> preferred;
  final Set<SoilTexture> acceptable;
  final Set<SoilTexture> caution;
}

const _sandySandyLoam = {SoilTexture.sandy, SoilTexture.sandyLoam};
const _claySandy = {SoilTexture.clay, SoilTexture.sandy};

const _fitByCropName = <String, _CropTextureTable>{
  'Rice (Palay)': _CropTextureTable(
    preferred: {SoilTexture.clay, SoilTexture.clayLoam},
    acceptable: {SoilTexture.loam},
    caution: _sandySandyLoam,
  ),
  'Corn (Mais)': _CropTextureTable(
    preferred: {SoilTexture.loam, SoilTexture.sandyLoam},
    acceptable: {SoilTexture.clayLoam},
    caution: _claySandy,
  ),
  'Tomato': _CropTextureTable(
    preferred: {SoilTexture.sandyLoam, SoilTexture.clayLoam},
    acceptable: {SoilTexture.loam},
    caution: _claySandy,
  ),
  'Eggplant': _CropTextureTable(
    preferred: {SoilTexture.sandyLoam, SoilTexture.clayLoam},
    acceptable: {SoilTexture.loam},
    caution: _claySandy,
  ),
  'Ampalaya': _CropTextureTable(
    preferred: {SoilTexture.sandyLoam, SoilTexture.loam},
    acceptable: {SoilTexture.clayLoam},
    caution: _claySandy,
  ),
  'Sitaw': _CropTextureTable(
    preferred: {SoilTexture.loam, SoilTexture.sandyLoam},
    acceptable: {SoilTexture.clayLoam},
    caution: _claySandy,
  ),
  'Okra': _CropTextureTable(
    preferred: {SoilTexture.sandyLoam, SoilTexture.loam},
    acceptable: {SoilTexture.clayLoam},
    caution: _claySandy,
  ),
  'Cabbage': _CropTextureTable(
    preferred: {SoilTexture.sandyLoam, SoilTexture.loam},
    acceptable: {SoilTexture.clayLoam},
    caution: _claySandy,
  ),
  'Onion': _CropTextureTable(
    preferred: {SoilTexture.loam, SoilTexture.sandyLoam},
    acceptable: {SoilTexture.clayLoam},
    caution: _claySandy,
  ),
  'Garlic': _CropTextureTable(
    preferred: {
      SoilTexture.sandyLoam,
      SoilTexture.loam,
      SoilTexture.clayLoam,
    },
    caution: _claySandy,
  ),
  'Chili': _CropTextureTable(
    preferred: {SoilTexture.sandyLoam, SoilTexture.clayLoam},
    acceptable: {SoilTexture.loam},
    caution: _claySandy,
  ),
  'Cucumber': _CropTextureTable(
    preferred: {SoilTexture.loam, SoilTexture.sandyLoam},
    acceptable: {SoilTexture.clayLoam},
    caution: _claySandy,
  ),
  'Squash': _CropTextureTable(
    preferred: {SoilTexture.sandyLoam, SoilTexture.clayLoam},
    acceptable: {SoilTexture.loam},
    caution: _claySandy,
  ),
  'Peanut': _CropTextureTable(
    preferred: {SoilTexture.sandyLoam, SoilTexture.loam},
    acceptable: {SoilTexture.clayLoam},
    caution: _claySandy,
  ),
  'Cassava': _CropTextureTable(
    preferred: {SoilTexture.sandyLoam, SoilTexture.clayLoam},
    acceptable: {SoilTexture.loam},
    caution: _claySandy,
  ),
  'Sweet potato': _CropTextureTable(
    preferred: {SoilTexture.sandyLoam, SoilTexture.loam},
    acceptable: {SoilTexture.clayLoam},
    caution: _claySandy,
  ),
  'Banana Saba': _CropTextureTable(
    preferred: {SoilTexture.loam, SoilTexture.clayLoam},
    acceptable: {SoilTexture.sandyLoam},
    caution: _claySandy,
  ),
};
