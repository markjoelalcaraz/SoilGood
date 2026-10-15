/// Data repository that reads the farmer's saved farm row from Supabase.
///
/// Weather uses lat/long; Crops match also reads [getPrimaryFarmSoilTexture].
/// Returns null when onboarding location was never finished.
library;

import '../../../core/soil/soil_series.dart';
import '../../../core/soil/soil_texture.dart';
import '../../../core/supabase/supabase_bootstrap.dart';

/// Farm coordinates used by weather and map features.
class FarmCoordinates {
  const FarmCoordinates({
    required this.farmId,
    required this.latitude,
    required this.longitude,
  });

  final String farmId;
  final double latitude;
  final double longitude;
}

/// Minimal farm row for the Home farm picker.
class FarmSummary {
  const FarmSummary({required this.id, required this.name});
  final String id;
  final String name;
}

/// Reads the signed-in user's farm pin from Supabase.
class FarmLocationRepository {
  /// All farms the signed-in user owns (farmer may add more later).
  Future<List<FarmSummary>> listFarms() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return const [];

    final rows = await supabase
        .from('farms')
        .select('id, name')
        .eq('owner_id', uid)
        .order('created_at', ascending: true);
    return [
      for (final row in (rows as List))
        FarmSummary(
          id: row['id'] as String,
          name: ((row['name'] as String?)?.trim().isEmpty ?? true)
              ? 'My farm'
              : (row['name'] as String).trim(),
        ),
    ];
  }

  /// First farm id for the signed-in user, even when lat/long is missing.
  Future<String?> getPrimaryFarmId() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return null;

    final row = await supabase
        .from('farms')
        .select('id')
        .eq('owner_id', uid)
        .limit(1)
        .maybeSingle();
    return row?['id'] as String?;
  }

  /// Display name of the primary farm, or null when the row has no name.
  Future<String?> getPrimaryFarmName() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return null;

    final row = await supabase
        .from('farms')
        .select('name')
        .eq('owner_id', uid)
        .limit(1)
        .maybeSingle();
    final name = (row?['name'] as String?)?.trim();
    if (name == null || name.isEmpty) return null;
    return name;
  }

  /// Farmer-selected texture on the primary farm, or null if unset.
  Future<SoilTexture?> getPrimaryFarmSoilTexture() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return null;

    final row = await supabase
        .from('farms')
        .select('soil_texture')
        .eq('owner_id', uid)
        .limit(1)
        .maybeSingle();

    return SoilTexture.fromWire(row?['soil_texture'] as String?);
  }

  /// Optional curated soil series on the primary farm (null = skip / unset).
  Future<SoilSeries?> getPrimaryFarmSoilSeries() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return null;

    final row = await supabase
        .from('farms')
        .select('soil_series')
        .eq('owner_id', uid)
        .limit(1)
        .maybeSingle();

    return SoilSeries.fromWire(row?['soil_series'] as String?);
  }

  /// Returns the first farm with valid lat/long, or null if missing.
  Future<FarmCoordinates?> getPrimaryFarmCoordinates() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return null;

    final row = await supabase
        .from('farms')
        .select('id, latitude, longitude')
        .eq('owner_id', uid)
        .limit(1)
        .maybeSingle();

    if (row == null) return null;
    final lat = row['latitude'];
    final lng = row['longitude'];
    if (lat == null || lng == null) return null;

    return FarmCoordinates(
      farmId: row['id'] as String,
      latitude: (lat as num).toDouble(),
      longitude: (lng as num).toDouble(),
    );
  }
}
