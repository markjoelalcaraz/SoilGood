/// Data repository that loads and watches the latest soil reading from Supabase.
///
/// Powers the live Home content area. Realtime stream shows new ESP32 inserts;
/// pull-to-refresh still calls [fetchLatest] so the farmer can force a reload.
library;

import '../../../core/soil/device_texture_resolver.dart';
import '../../../core/supabase/supabase_bootstrap.dart';
import 'soil_reading.dart';

/// Loads and streams soil readings belonging to the signed-in farmer.
///
/// Moisture comes back as texture-aware wetness (see `soil_wetness.dart`).
class SoilReadingsRepository {
  final _textures = DeviceTextureResolver();

  /// Returns device IDs for all farms owned by the current user.
  Future<List<String>> _ownedDeviceIds() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return [];

    final farms = await supabase.from('farms').select('id').eq('owner_id', uid);

    final farmIds = (farms as List).map((e) => e['id'] as String).toList();
    if (farmIds.isEmpty) return [];

    final devices = await supabase
        .from('devices')
        .select('id')
        .inFilter('farm_id', farmIds);

    return (devices as List).map((e) => e['id'] as String).toList();
  }

  /// Latest reading once (used for first paint / cache-style load).
  Future<SoilReading?> fetchLatest() async {
    final deviceIds = await _ownedDeviceIds();
    if (deviceIds.isEmpty) return null;

    final row = await supabase
        .from('soil_readings')
        .select()
        .inFilter('device_id', deviceIds)
        .order('recorded_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (row == null) return null;
    return _textures.normalize(SoilReading.fromJson(row));
  }

  /// Live updates via Supabase Realtime stream on `soil_readings`.
  Stream<SoilReading?> watchLatest() async* {
    final deviceIds = await _ownedDeviceIds();
    if (deviceIds.isEmpty) {
      yield null;
      return;
    }

    yield* supabase
        .from('soil_readings')
        .stream(primaryKey: ['id'])
        .order('recorded_at', ascending: false)
        .asyncMap((rows) async {
          final owned = rows.where((r) => deviceIds.contains(r['device_id']));
          if (owned.isEmpty) return null;
          return _textures.normalize(
            SoilReading.fromJson(Map<String, dynamic>.from(owned.first)),
          );
        });
  }
}
