/// Pure session / ownership helpers for farmer data access (unit-testable).
///
/// Mirrors how [SoilReadingsRepository] scopes by `owner_id` → farm → device.
/// Full RLS still lives in Supabase; these rules catch client-side mistakes
/// (no session, forged farm_id, leaking `ingest_token`). TC_AUTH_001 / 002.
library;

/// Message when a farmer path runs without a signed-in user.
const String kNoSignedInUserMessage = 'No signed-in user.';

/// Requires a non-empty session user id (Supabase Auth uid).
String requireSignedInUserId(String? uid) {
  final id = uid?.trim() ?? '';
  if (id.isEmpty) {
    throw StateError(kNoSignedInUserMessage);
  }
  return id;
}

/// Farm ids whose `owner_id` matches [uid]. Ignores foreign farms.
List<String> farmIdsOwnedBy({
  required String uid,
  required Iterable<Map<String, dynamic>> farms,
}) {
  return farms
      .where((f) => f['owner_id'] == uid)
      .map((f) => f['id'] as String)
      .toList();
}

/// Device ids whose `farm_id` is in [ownedFarmIds].
List<String> deviceIdsForOwnedFarms({
  required Iterable<String> ownedFarmIds,
  required Iterable<Map<String, dynamic>> devices,
}) {
  final allowed = ownedFarmIds.toSet();
  return devices
      .where((d) {
        final farmId = d['farm_id'] as String?;
        return farmId != null && allowed.contains(farmId);
      })
      .map((d) => d['id'] as String)
      .toList();
}

/// Keeps only soil rows whose `device_id` is in [ownedDeviceIds].
List<Map<String, dynamic>> soilRowsForOwnedDevices({
  required Iterable<Map<String, dynamic>> rows,
  required Iterable<String> ownedDeviceIds,
}) {
  final allowed = ownedDeviceIds.toSet();
  return rows
      .where((r) => allowed.contains(r['device_id'] as String?))
      .map(Map<String, dynamic>.from)
      .toList();
}

/// Farmer-facing device map: strips ingest secrets. Claim never returns these.
Map<String, dynamic> farmerSafeDeviceRow(Map<String, dynamic> row) {
  final out = Map<String, dynamic>.from(row);
  out.remove('ingest_token');
  out.remove('ingestToken');
  return out;
}

/// Client `.env` must only hold the anon key name — never service_role.
bool isForbiddenClientSupabaseKeyName(String keyName) {
  final n = keyName.trim().toUpperCase();
  return n.contains('SERVICE_ROLE') || n == 'SERVICE_ROLE_KEY';
}
