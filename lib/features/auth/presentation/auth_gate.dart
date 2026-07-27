/// Root router after main — decides login vs onboarding vs the app shell.
///
/// Listens to Supabase auth. If logged out → Login. If logged in but profile/farm/
/// device incomplete → the matching onboarding page. If ready → AppShell. This file
/// is navigation logic, not a farmer-facing content page by itself.
library;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_bootstrap.dart';
import '../../../core/theme/app_colors.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../../onboarding/presentation/device_onboarding_page.dart';
import '../../onboarding/presentation/location_onboarding_page.dart';
import '../../onboarding/presentation/profile_onboarding_page.dart';
import '../../shell/app_shell.dart';
import 'login_page.dart';

/// Routes by auth session, then by onboarding progress (profile → GPS → device).
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      initialData: AuthState(
        AuthChangeEvent.initialSession,
        supabase.auth.currentSession,
      ),
      builder: (context, snapshot) {
        final session = snapshot.data?.session;
        if (session == null) {
          return const LoginPage(key: ValueKey('login'));
        }
        return const _OnboardingRouter(key: ValueKey('onboarding-router'));
      },
    );
  }
}

/// Loads the next onboarding step from Supabase for the signed-in user.
class _OnboardingRouter extends StatefulWidget {
  const _OnboardingRouter({super.key});

  @override
  State<_OnboardingRouter> createState() => _OnboardingRouterState();
}

class _OnboardingRouterState extends State<_OnboardingRouter> {
  late Future<OnboardingStep> _future;

  @override
  void initState() {
    super.initState();
    _future = OnboardingRepository().loadStep();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<OnboardingStep>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load onboarding status:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.error, height: 1.5),
                ),
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return switch (snapshot.data!) {
          OnboardingStep.profile => const ProfileOnboardingPage(
            key: ValueKey('profile-step'),
          ),
          OnboardingStep.location => const LocationOnboardingPage(
            key: ValueKey('location-step'),
          ),
          OnboardingStep.device => const DeviceOnboardingPage(
            key: ValueKey('device-step'),
          ),
          OnboardingStep.done => const AppShell(key: ValueKey('shell')),
        };
      },
    );
  }
}
