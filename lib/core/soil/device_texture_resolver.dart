/// Data-layer helper that knows which soil texture each sensor sits in.
///
/// Used by the soil reading repositories (Home, Farm, Crops, Analytics,
/// notifications) to turn the probe's raw moisture into wetness. A kit on an
/// active crop plot uses that plot's texture (from Add a crop); otherwise the
/// farm's texture from onboarding. Not a widget.
library;

import '../../features/home/data/soil_reading.dart';
import '../supabase/supabase_bootstrap.dart';
import 'soil_texture.dart';

/// Caches device → texture for a short time so streams stay cheap.
class DeviceTextureResolver {
  static const _ttl = Duration(minutes: 2);

  Map<String, SoilTexture?> _byDevice = {};
  SoilTexture? _farmTexture;
  DateTime? _loadedAt;
  Future<void>? _loading;

  /// Forces the next call to reload (e.g. after a sensor was placed on a plot).
  void invalidate() => _loadedAt = null;

  /// [reading] with wetness for its sensor's texture.
  Future<SoilReading> normalize(SoilReading reading) async {
    await _ensureLoaded(reading.deviceId);
    return reading.withWetness(textureFor(reading.deviceId));
  }

  /// Same as [normalize] for many rows (Analytics history).
  Future<List<SoilReading>> normalizeAll(List<SoilReading> readings) async {
    if (readings.isEmpty) return readings;
    await _ensureLoaded(null);
    return [for (final r in readings) r.withWetness(textureFor(r.deviceId))];
  }

  /// Farm texture from onboarding, for farm-wide aggregates (Analytics buckets).
  Future<SoilTexture?> farmTexture() async {
    await _ensureLoaded(null);
    return _farmTexture;
  }

  /// Plot texture for an active plot, else the farm texture (null = default scale).
  SoilTexture? textureFor(String? deviceId) {
    if (deviceId != null && _byDevice.containsKey(deviceId)) {
      return _byDevice[deviceId] ?? _farmTexture;
    }
    return _farmTexture;
  }

  /// Reloads when stale, or when a reading comes from a kit we have not seen.
  Future<void> _ensureLoaded(String? deviceId) async {
    final fresh = _loadedAt != null &&
        DateTime.now().difference(_loadedAt!) < _ttl &&
        (deviceId == null || _byDevice.containsKey(deviceId));
    if (fresh) return;
    _loading ??= _load().whenComplete(() => _loading = null);
    await _loading;
  }

  Future<void> _load() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;

    final farm = await supabase
        .from('farms')
        .select('soil_texture')
        .eq('owner_id', uid)
        .order('created_at', ascending: true)
        .limit(1)
        .maybeSingle();
    final rows = await supabase
        .from('devices')
        .select('id, plantings(status, soil_texture)');

    final byDevice = <String, SoilTexture?>{};
    for (final raw in rows as List) {
      final json = Map<String, dynamic>.from(raw as Map);
      final plot = json['plantings'];
      SoilTexture? texture;
      if (plot is Map && plot['status'] == 'active') {
        texture = SoilTexture.fromWire(plot['soil_texture'] as String?);
      }
      byDevice[json['id'] as String] = texture;
    }

    _farmTexture = SoilTexture.fromWire(farm?['soil_texture'] as String?);
    _byDevice = byDevice;
    _loadedAt = DateTime.now();
  }
}
