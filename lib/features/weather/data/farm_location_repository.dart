/// Data repository that reads the farmer's saved farm coordinates from Supabase.
///
/// Weather uses lat/long; Crops and Home AI use [getPrimaryFarmId] even when
/// the pin is missing. Returns null when onboarding location was never finished.
library;

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

/// Reads the signed-in user's farm pin from Supabase.
class FarmLocationRepository {
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
