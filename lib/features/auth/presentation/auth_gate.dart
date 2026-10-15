/// Root router after the index splash — login vs admin website vs farmer app.
///
/// Listens to Supabase auth. Logged out → Login. A password-reset link →
/// choose a new password. Logged in → load profiles.role: admin → AdminShell
/// (website ops UI). farmer → onboarding / AppShell on any platform (phone
/// product; Chrome still works for testing). Navigation only.
library;

import 'dart:async';

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
import '../logic/password_recovery.dart';
import 'login_page.dart';
import 'set_new_password_page.dart';
import 'splash_page.dart';

/// Plays the index splash once, then the session router underneath.
class SoilGoodStart extends StatefulWidget {
  const SoilGoodStart({super.key});

  @override
  State<SoilGoodStart> createState() => _SoilGoodStartState();
}

class _SoilGoodStartState extends State<SoilGoodStart> {
  bool _opened = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AppReveal(ready: _opened, child: const AuthGate()),
        if (!_opened)
          SplashPage(
            onFinished: () {
              if (mounted) setState(() => _opened = true);
            },
          ),
      ],
    );
  }
}

/// Routes by auth session, then role, then onboarding progress.
///
/// A password-reset link holds the farmer on [SetNewPasswordPage] until they
/// save a new password.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _recovery = const PasswordRecoveryStore();
  StreamSubscription<AuthState>? _authSub;
  var _chooseNewPassword = false;

  @override
  void initState() {
    super.initState();
    _chooseNewPassword =
        PasswordRecoveryLaunch.pending || uriRequestsPasswordRecovery(Uri.base);
    if (_chooseNewPassword) {
      unawaited(_recovery.write(true));
    } else {
      unawaited(_restoreRecoveryFlag());
    }
    _authSub = supabase.auth.onAuthStateChange.listen((state) {
      if (!mounted) return;
      if (state.event == AuthChangeEvent.passwordRecovery) {
        unawaited(_recovery.write(true));
        setState(() => _chooseNewPassword = true);
      }
    });
  }

  /// A refresh can drop the URL flag while the recovery session is still stored.
  Future<void> _restoreRecoveryFlag() async {
    final pending = await _recovery.read();
    if (!mounted || !pending) return;
    if (supabase.auth.currentSession == null) {
      await _recovery.write(false);
      return;
    }
    setState(() => _chooseNewPassword = true);
  }

  /// Leaves the reset screen and continues into the signed-in app.
  Future<void> _passwordSaved() async {
    await _recovery.write(false);
    if (mounted) setState(() => _chooseNewPassword = false);
  }

  @override
  void dispose() {
    unawaited(_authSub?.cancel() ?? Future<void>.value());
    super.dispose();
  }

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
        if (_chooseNewPassword && session != null) {
          return SetNewPasswordPage(
            key: const ValueKey('set-password'),
            onSaved: () => unawaited(_passwordSaved()),
          );
        }
        if (_chooseNewPassword &&
            session == null &&
            uriRequestsPasswordRecovery(Uri.base)) {
          return const Scaffold(
            key: ValueKey('recovery-wait'),
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (session == null && PasswordRecoveryLaunch.error != null) {
          return _RecoveryLinkProblem(
            key: const ValueKey('recovery-problem'),
            message: PasswordRecoveryLaunch.error!,
            onBack: () {
              PasswordRecoveryLaunch.error = null;
              setState(() {});
            },
          );
        }
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

/// Shown when the email link reached SoilGood but did not start a reset session.
class _RecoveryLinkProblem extends StatelessWidget {
  const _RecoveryLinkProblem({
    required this.message,
    required this.onBack,
    super.key,
  });

  final String message;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    message,
                    style: const TextStyle(
                      color: AppColors.error,
                      height: 1.45,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: onBack,
                      child: const Text('Back to sign in'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
