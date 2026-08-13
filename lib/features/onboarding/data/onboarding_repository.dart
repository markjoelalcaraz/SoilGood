/// Data layer for first-run onboarding: profile, farm pin, device claim, and next-step checks.
///
/// AuthGate asks this repository which onboarding screen to show. The three
/// onboarding pages call it to save rows to Supabase. No UI here.
library;

import 'dart:math';

import '../../../core/supabase/supabase_bootstrap.dart';

/// Which onboarding screen the signed-in user should see next.
enum OnboardingStep { profile, location, device, done }

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
    if (firstName.isEmpty) return OnboardingStep.profile;

    final farms = await supabase
        .from('farms')
        .select('id')
        .eq('owner_id', uid)
        .limit(1);

    if ((farms as List).isEmpty) return OnboardingStep.location;

    final farmId = farms.first['id'] as String;
    final devices = await supabase
        .from('devices')
        .select('id')
        .eq('farm_id', farmId)
        .limit(1);

    if ((devices as List).isEmpty) return OnboardingStep.device;
    return OnboardingStep.done;
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

  /// Random hex token the ESP32 sends with the anon key (not service_role).
  String _newIngestToken() {
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Links an ESP32 `device_uid` to the user's farm. Returns `ingest_token`.
  Future<String> claimDevice({
    required String deviceUid,
    String name = 'SoilGood Sensor',
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
      throw StateError('Create a farm location before claiming a device.');
    }

    final farmId = farms.first['id'] as String;
    final uidTrim = deviceUid.trim();

    final existing = await supabase
        .from('devices')
        .select('id, farm_id, ingest_token')
        .eq('device_uid', uidTrim)
        .maybeSingle();

    if (existing != null) {
      if (existing['farm_id'] != farmId) {
        throw StateError('This device is already linked to another farm.');
      }
      final existingToken = (existing['ingest_token'] as String?)?.trim() ?? '';
      if (existingToken.isNotEmpty) {
        await supabase
            .from('devices')
            .update({'status': 'active', 'name': name})
            .eq('id', existing['id']);
        return existingToken;
      }
      final updated = await supabase
          .from('devices')
          .update({
            'status': 'active',
            'name': name,
            'ingest_token': _newIngestToken(),
          })
          .eq('id', existing['id'])
          .select('ingest_token')
          .single();
      return updated['ingest_token'] as String;
    }

    final inserted = await supabase
        .from('devices')
        .insert({
          'farm_id': farmId,
          'device_uid': uidTrim,
          'name': name,
          'status': 'active',
          'ingest_token': _newIngestToken(),
        })
        .select('ingest_token')
        .single();
    return inserted['ingest_token'] as String;
  }
}
