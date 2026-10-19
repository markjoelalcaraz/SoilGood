/// Loads the crops catalog and the farm’s active plantings from Supabase.
///
/// Data layer for the Crops list, Farm tab, and Home. A farm can grow several
/// crops at once (one plot each). Match scores and phase math live in `logic/`.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/soil/soil_series.dart';
import '../../../core/soil/soil_texture.dart';
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

  /// Every active crop on [farmId], oldest first (one plot per crop).
  Future<List<Planting>> fetchActivePlantings(String farmId) async {
    final rows = await supabase
        .from('plantings')
        .select('*, crops(*)')
        .eq('farm_id', farmId)
        .eq('status', 'active')
        .order('created_at', ascending: true);
    return [
      for (final row in rows as List)
        Planting.fromJson(Map<String, dynamic>.from(row as Map)),
    ];
  }

  /// Newest active planting for [farmId], or null if nothing is planted.
  ///
  /// Farm-wide jobs (notifications) still use one crop for context.
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
  /// or if this crop is already active on the farm (DB unique index).
  ///
  /// Soil fields are the plot's own soil from Add a crop (null = not recorded).
  Future<Planting> selectCrop({
    required String farmId,
    required CropCatalogEntry crop,
    SoilTexture? soilTexture,
    SoilSeries? soilSeries,
    String? soilSeriesOther,
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
            if (soilTexture != null) 'soil_texture': soilTexture.wire,
            if (soilSeries != null) 'soil_series': soilSeries.wire,
            if (soilSeries == SoilSeries.other &&
                (soilSeriesOther?.trim().isNotEmpty ?? false))
              'soil_series_other': soilSeriesOther!.trim(),
          })
          .select('*, crops(*)')
          .single();

      return Planting.fromJson(inserted);
    } on PostgrestException catch (e) {
      // 23505 = unique_violation. Old DB: one crop per farm. New DB: same crop twice.
      if (e.code == '23505') {
        throw StateError(
          '${crop.name} is already planted, or your database still allows only '
          'one crop per farm. Run docs/context/supabase_multi_crop.sql in Supabase.',
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
