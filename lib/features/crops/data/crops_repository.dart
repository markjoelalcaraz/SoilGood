/// Loads the crops catalog and the farm’s active planting from Supabase.
///
/// Crops tab data layer only. Match scores and phase math live in `logic/`.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_bootstrap.dart';
import '../../analytics/logic/manila_time.dart';
import 'crop_catalog.dart';
import 'planting.dart';

/// Catalog + plantings for the signed-in farmer’s primary farm.
class CropsRepository {
  /// Every reference crop (small table).
  Future<List<CropCatalogEntry>> fetchCatalog() async {
    final rows = await supabase.from('crops').select().order('name');
    return (rows as List)
        .map(
          (e) => CropCatalogEntry.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  /// Active planting for [farmId], or null if the farmer has not selected a crop.
  Future<Planting?> fetchActivePlanting(String farmId) async {
    final row = await supabase
        .from('plantings')
        .select('*, crops(*)')
        .eq('farm_id', farmId)
        .eq('status', 'active')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;
    return Planting.fromJson(row);
  }

  /// Inserts today’s planting. Fails if [crop] has no `days_to_maturity`,
  /// or if the farm already has an active planting (DB unique index).
  Future<Planting> selectCrop({
    required String farmId,
    required CropCatalogEntry crop,
  }) async {
    final days = crop.daysToMaturity;
    if (days == null || days <= 0) {
      throw StateError(
        'Crop catalog is missing days_to_maturity. Run supabase_crops_home_ai.sql.',
      );
    }

    final today = manilaCalendarDate(DateTime.now());
    final harvest = today.add(Duration(days: days));
    final plantedStr = _ymd(today);
    final harvestStr = _ymd(harvest);

    try {
      final inserted = await supabase
          .from('plantings')
          .insert({
            'farm_id': farmId,
            'crop_id': crop.id,
            'planted_at': plantedStr,
            'expected_harvest_at': harvestStr,
            'status': 'active',
          })
          .select('*, crops(*)')
          .single();

      return Planting.fromJson(inserted);
    } on PostgrestException catch (e) {
      // 23505 = unique_violation (plantings_one_active_per_farm_uidx).
      if (e.code == '23505') {
        throw StateError(
          'This farm already has an active crop. Change crop first, then select again.',
        );
      }
      rethrow;
    }
  }

  /// Ends the active planting (Change crop) so the suitable-crop list can show again.
  Future<void> endPlanting(String plantingId) async {
    await supabase
        .from('plantings')
        .update({'status': 'replaced'})
        .eq('id', plantingId);
  }

  static String _ymd(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }
}
