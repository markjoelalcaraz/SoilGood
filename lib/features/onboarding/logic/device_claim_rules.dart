/// Pure claim-code rules for device onboarding (no Supabase / UI).
///
/// Used by [OnboardingRepository.claimDevice] and unit tests for
/// TC_DEVICE_001 / TC_DEVICE_002. Keeps trim/upper + farmer-facing error
/// mapping in one place so RPC message text cannot drift from tests.
library;

/// Normalizes a sticker claim code the way the claim RPC expects it.
///
/// Returns null when the farmer left the field empty (after trim).
String? normalizeClaimCode(String raw) {
  final code = raw.trim().toUpperCase();
  if (code.isEmpty) return null;
  return code;
}

/// Maps Postgrest / Postgres claim failures to short farmer-facing copy.
String friendlyClaimError(Object error) {
  final raw = error.toString();
  const known = [
    'Enter the claim code from your sensor box',
    'Create your farm location before linking a sensor',
    'This farm already has a sensor linked',
    'Claim code not found. Check the code on your box',
    'This claim code was already used',
    'That plot is not on your farm',
    'Choose the current crop for this sensor',
    'Sensor not on your farm',
    'Choose a sensor and a plot',
    'Not signed in',
  ];
  for (final msg in known) {
    if (raw.contains(msg)) return msg;
  }
  if (raw.contains('claim_device') || raw.contains('PGRST')) {
    return 'Could not link sensor. Ask your installer to run device claim SQL, then try again.';
  }
  return raw;
}

/// Empty-field message shown before calling the claim RPC.
const String kEmptyClaimCodeMessage =
    'Enter the claim code from your sensor box.';
