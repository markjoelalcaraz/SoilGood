/// Pure onboarding gate: which step the farmer still needs.
///
/// Used by [OnboardingRepository.loadStep] after Supabase rows are loaded, and
/// by automated tests so the order (profile, pin, texture, device) stays fixed.
library;

/// Which onboarding screen the signed-in user should see next.
enum OnboardingStep { profile, location, soilTexture, device, done }

/// Next screen from saved profile, farm, texture, and device facts.
OnboardingStep nextOnboardingStep({
  required String firstName,
  required bool hasFarm,
  required String? soilTexture,
  required bool hasDevice,
}) {
  if (firstName.trim().isEmpty) return OnboardingStep.profile;
  if (!hasFarm) return OnboardingStep.location;
  final texture = soilTexture?.trim() ?? '';
  if (texture.isEmpty) return OnboardingStep.soilTexture;
  if (!hasDevice) return OnboardingStep.device;
  return OnboardingStep.done;
}
