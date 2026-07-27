/// Data repository that loads and watches the latest soil reading from Supabase.
///
/// Powers the live Home content area. Prefer the realtime stream so new ESP32
/// inserts appear without the farmer refreshing manually.
library;

import '../../../core/supabase/supabase_bootstrap.dart';
import 'soil_reading.dart';

/// Loads and streams soil readings belonging to the signed-in farmer.
class SoilReadingsRepository {
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
    return SoilReading.fromJson(row);
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
        .map((rows) {
          final owned = rows.where((r) => deviceIds.contains(r['device_id']));
          if (owned.isEmpty) return null;
          return SoilReading.fromJson(Map<String, dynamic>.from(owned.first));
        });
  }
}
