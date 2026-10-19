/// Converts the probe's raw moisture into "wetness" for the soil's texture.
///
/// Logic only (no Supabase, no widgets). The 8-in-1 probe reports volumetric
/// water content: sandy loam is soaked at ~41%, clay at ~50%. Crop ranges and
/// app bands use a 0–100 scale where 100 = soaked, so every reading is divided
/// by its texture's saturation first. Without this, sandy soil always looks dry.
library;

import 'soil_texture.dart';

/// Approximate saturation (probe %) per texture — typical soil-physics values
/// (Saxton & Rawls class averages), rounded. Field checks may refine these.
const kSaturationByTexture = <SoilTexture, double>{
  SoilTexture.sandy: 38,
  SoilTexture.sandyLoam: 41,
  SoilTexture.loam: 43,
  SoilTexture.clayLoam: 47,
  SoilTexture.clay: 50,
};

/// Used when the texture is unknown / not set: loam, the middle class.
const kDefaultSaturation = 43.0;

/// Probe % this far above saturation suggests the farmer picked the wrong texture.
const kTextureMismatchMargin = 8.0;

/// Saturation (probe %) for [texture]; loam when unknown.
double saturationFor(SoilTexture? texture) =>
    kSaturationByTexture[texture] ?? kDefaultSaturation;

/// Wetness 0–100 (100 = soaked) from the probe's raw moisture %.
double wetnessFromSensor(double sensorPercent, SoilTexture? texture) {
  final wet = sensorPercent / saturationFor(texture) * 100;
  return wet.clamp(0, 100).toDouble();
}

/// True when the probe reads well above what [texture] can physically hold.
///
/// Standing water also does this, so the UI words it as "check", not "wrong".
bool sensorAboveTextureSaturation(double sensorPercent, SoilTexture? texture) {
  if (texture == null || texture == SoilTexture.unknown) return false;
  return sensorPercent > saturationFor(texture) + kTextureMismatchMargin;
}
