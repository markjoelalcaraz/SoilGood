/// SoilGood Lab Flasher — Windows desktop entrypoint.
///
/// Standalone station app under tooling/lab_flasher. Admins provision a kit
/// in Supabase and inject credentials over USB serial (SGCFG). Not the farmer
/// mobile app and not the Flutter Web AdminShell.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/lab_env.dart';
import 'presentation/auth_gate.dart';
import 'theme/app_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LabEnv.load();
  await Supabase.initialize(
    url: LabEnv.supabaseUrl,
    anonKey: LabEnv.supabaseAnonKey, // ignore: deprecated_member_use
  );
  runApp(const LabFlasherApp());
}

/// Root MaterialApp for the lab station window.
class LabFlasherApp extends StatelessWidget {
  const LabFlasherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SoilGood Lab Flasher',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          surface: AppColors.surface,
        ),
        scaffoldBackgroundColor: AppColors.background,
        textTheme: GoogleFonts.nunitoSansTextTheme(),
        useMaterial3: true,
      ),
      home: const LabAuthGate(),
    );
  }
}
