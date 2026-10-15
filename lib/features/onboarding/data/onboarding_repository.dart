/// Data layer for first-run onboarding: profile, farm pin, soil texture, device claim.
///
/// AuthGate asks this repository which onboarding screen to show. Onboarding
/// pages save rows to Supabase. Device claim uses RPC `claim_device`
/// (lab-preprovisioned kits). No UI here.
library;

import '../../../core/soil/soil_series.dart';
import '../../../core/soil/soil_texture.dart';
import '../../../core/supabase/supabase_bootstrap.dart';
import '../logic/device_claim_rules.dart';
import '../logic/onboarding_step_rules.dart';

export '../logic/onboarding_step_rules.dart' show OnboardingStep;

/// Reads/writes profile, farm, and device rows used by onboarding.
class OnboardingRepository {
  /// Decides the next onboarding step from existing Supabase rows.
  Future<OnboardingStep> loadStep() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) {
      throw StateError('No signed-in user for onboarding.');
    }

    final profile = await supabase
        .from('profiles')
        .select('first_name')
        .eq('id', uid)
        .maybeSingle();

    final firstName = (profile?['first_name'] as String?)?.trim() ?? '';

    final farms = await supabase
        .from('farms')
        .select('id, soil_texture')
        .eq('owner_id', uid)
        .limit(1);

    final farmList = farms as List;
    final hasFarm = farmList.isNotEmpty;
    final soilTexture = hasFarm ? farmList.first['soil_texture'] as String? : null;

    var hasDevice = false;
    if (hasFarm) {
      final farmId = farmList.first['id'] as String;
      final devices = await supabase
          .from('devices')
          .select('id')
          .eq('farm_id', farmId)
          .limit(1);
      hasDevice = (devices as List).isNotEmpty;
    }

    return nextOnboardingStep(
      firstName: firstName,
      hasFarm: hasFarm,
      soilTexture: soilTexture,
      hasDevice: hasDevice,
    );
  }

  /// Loads the current profile fields for edit forms.
  Future<Map<String, dynamic>?> loadProfile() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return null;
    return supabase.from('profiles').select().eq('id', uid).maybeSingle();
  }

  /// Saves name + address to `profiles`.
  Future<void> saveProfile({
    required String firstName,
    required String lastName,
    required String barangay,
    required String municipalityCity,
    required String province,
  }) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) {
      throw StateError('No signed-in user.');
    }

    await supabase
        .from('profiles')
        .update({
          'first_name': firstName.trim(),
          'last_name': lastName.trim(),
          'barangay': barangay.trim(),
          'municipality_city': municipalityCity.trim(),
          'province': province.trim(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', uid);
  }

  /// Creates the farmer's first farm with confirmed map coordinates.
  Future<String> saveFarmLocation({
    required String name,
    required String barangay,
    required String municipalityCity,
    required String province,
    required double latitude,
    required double longitude,
  }) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) {
      throw StateError('No signed-in user.');
    }

    final existing = await supabase
        .from('farms')
        .select('id')
        .eq('owner_id', uid)
        .limit(1);

    if ((existing as List).isNotEmpty) {
      final id = existing.first['id'] as String;
      await supabase
          .from('farms')
          .update({
            'name': name.trim(),
            'barangay': barangay.trim(),
            'municipality_city': municipalityCity.trim(),
            'province': province.trim(),
            'latitude': latitude,
            'longitude': longitude,
          })
          .eq('id', id);
      return id;
    }

    final row = await supabase
        .from('farms')
        .insert({
          'owner_id': uid,
          'name': name.trim(),
          'barangay': barangay.trim(),
          'municipality_city': municipalityCity.trim(),
          'province': province.trim(),
          'latitude': latitude,
          'longitude': longitude,
        })
        .select('id')
        .single();

    return row['id'] as String;
  }

  /// Saves required texture + optional curated soil series on the primary farm.
  Future<void> saveSoilPhysicalProfile({
    required SoilTexture texture,
    SoilSeries? series,
    String? seriesOther,
  }) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) {
      throw StateError('No signed-in user.');
    }

    final farms = await supabase
        .from('farms')
        .select('id')
        .eq('owner_id', uid)
        .limit(1);

    if ((farms as List).isEmpty) {
      throw StateError('Save your farm location before choosing soil type.');
    }

    final farmId = farms.first['id'] as String;
    final other = seriesOther?.trim();
    await supabase.from('farms').update({
      'soil_texture': texture.wire,
      'soil_series': series?.wire,
      'soil_series_other':
          series == SoilSeries.other && other != null && other.isNotEmpty
              ? other
              : null,
    }).eq('id', farmId);
  }

  /// Links a lab-preprovisioned kit via sticker claim code. Never returns ingest_token.
  Future<void> claimDevice({required String claimCode}) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) {
      throw StateError('No signed-in user.');
    }

    final code = normalizeClaimCode(claimCode);
    if (code == null) {
      throw StateError(kEmptyClaimCodeMessage);
    }

    try {
      await supabase.rpc('claim_device', params: {'p_claim_code': code});
    } on Object catch (e) {
      throw StateError(friendlyClaimError(e));
    }
  }
}
