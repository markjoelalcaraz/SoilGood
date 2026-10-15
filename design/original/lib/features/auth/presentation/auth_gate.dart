/// Root router after main — login vs admin website vs farmer app.
///
/// Listens to Supabase auth. Logged out → Login. Logged in → load profiles.role:
/// admin → AdminShell (website ops UI). farmer → onboarding / AppShell on any
/// platform (phone product; Chrome still works for testing). Navigation only.
library;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_bootstrap.dart';
import '../../../core/theme/app_colors.dart';
import '../../admin/data/profile_role_repository.dart';
import '../../admin/presentation/admin_shell.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../../onboarding/presentation/device_onboarding_page.dart';
import '../../onboarding/presentation/location_onboarding_page.dart';
import '../../onboarding/presentation/profile_onboarding_page.dart';
import '../../onboarding/presentation/soil_texture_onboarding_page.dart';
import '../../shell/app_shell.dart';
import 'login_page.dart';

/// Routes by auth session, then role, then onboarding progress.
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
        return const _RoleRouter(key: ValueKey('role-router'));
      },
    );
  }
}

/// Loads profiles.role then sends admins and farmers down different trees.
class _RoleRouter extends StatefulWidget {
  const _RoleRouter({super.key});

  @override
  State<_RoleRouter> createState() => _RoleRouterState();
}

class _RoleRouterState extends State<_RoleRouter> {
  late Future<AppRole> _future;

  @override
  void initState() {
    super.initState();
    _future = ProfileRoleRepository().loadCurrentRole();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppRole>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load account role:\n${snapshot.error}',
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

        // Admin → website ops console. Farmer → same app on phone or Chrome.
        if (snapshot.data == AppRole.admin) {
          return const AdminShell(key: ValueKey('admin-shell'));
        }

        return const _OnboardingRouter(key: ValueKey('onboarding-router'));
      },
    );
  }
}

/// Loads the next onboarding step from Supabase for the signed-in farmer.
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
          OnboardingStep.soilTexture => const SoilTextureOnboardingPage(
            key: ValueKey('soil-texture-step'),
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
