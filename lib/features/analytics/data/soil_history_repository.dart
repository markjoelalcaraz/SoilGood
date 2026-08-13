/// Loads aggregated soil history and a single day's raw readings from Supabase.
///
/// Powers the Analytics tab only. Home still uses [SoilReadingsRepository]
/// `fetchLatest` / `watchLatest`. Daily series come from RPC `analytics_soil_daily`.
library;

import '../../../core/supabase/supabase_bootstrap.dart';
import '../../home/data/soil_reading.dart';
import '../logic/manila_time.dart';
import 'daily_soil_bucket.dart';

/// History fetch for Analytics charts and the day-readings drill-down.
class SoilHistoryRepository {
  /// Daily buckets for an inclusive Manila calendar range.
  Future<List<DailySoilBucket>> fetchDaily({
    required DateTime start,
    required DateTime end,
  }) async {
    final range = manilaRangeUtcForDates(start, end);
    final raw = await supabase.rpc(
      'analytics_soil_daily',
      params: {
        'p_from': range.from.toIso8601String(),
        'p_to': range.to.toIso8601String(),
      },
    );

    final rows = (raw as List).cast<dynamic>();
    return rows
        .map((e) => DailySoilBucket.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Timestamped readings for one Manila calendar day (tap-a-day history).
  Future<List<SoilReading>> fetchForDay(DateTime manilaDate) async {
    final deviceIds = await _ownedDeviceIds();
    if (deviceIds.isEmpty) return [];

    final from = manilaMidnightUtc(
      manilaDate.year,
      manilaDate.month,
      manilaDate.day,
    );
    final to = manilaDayEndUtc(manilaDate.year, manilaDate.month, manilaDate.day);

    final rows = await supabase
        .from('soil_readings')
        .select()
        .inFilter('device_id', deviceIds)
        .gte('recorded_at', from.toIso8601String())
        .lt('recorded_at', to.toIso8601String())
        .order('recorded_at', ascending: true);

    return (rows as List)
        .map((e) => SoilReading.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Optional crop name for the active planting, used as Groq context.
  Future<String?> fetchActiveCropName() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return null;

    final farm = await supabase
        .from('farms')
        .select('id')
        .eq('owner_id', uid)
        .limit(1)
        .maybeSingle();
    if (farm == null) return null;

    final planting = await supabase
        .from('plantings')
        .select('crops(name)')
        .eq('farm_id', farm['id'] as String)
        .eq('status', 'active')
        .limit(1)
        .maybeSingle();
    if (planting == null) return null;

    final crop = planting['crops'];
    if (crop is Map && crop['name'] is String) {
      return crop['name'] as String;
    }
    return null;
  }

  Future<String?> fetchPrimaryFarmId() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return null;
    final farm = await supabase
        .from('farms')
        .select('id')
        .eq('owner_id', uid)
        .limit(1)
        .maybeSingle();
    return farm?['id'] as String?;
  }

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
}
