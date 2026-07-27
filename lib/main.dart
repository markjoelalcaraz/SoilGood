/// App entry point for SoilGood — the first Dart code that runs on launch.
///
/// Loads secrets from .env, connects to Supabase, then starts the Flutter app
/// with the shared theme and AuthGate (login / onboarding / shell routing).
library;

import 'package:flutter/material.dart';

import 'core/config/app_env.dart';
import 'core/supabase/supabase_bootstrap.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load secrets from .env, then connect to Supabase (fail visibly if misconfigured).
  await AppEnv.load();
  await bootstrapSupabase();

  runApp(const SoilGoodApp());
}

/// Root widget that applies the shared theme and session-aware auth gate.
class SoilGoodApp extends StatelessWidget {
  const SoilGoodApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SoilGood',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AuthGate(),
    );
  }
}
