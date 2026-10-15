/// Isolated UX preview entry — soil onboarding dropdowns only.
///
/// Not wired to AuthGate, Supabase, or the real onboarding flow. Run with:
/// `flutter run -t lib/dev/main_soil_onboarding_ux_mock.dart`
/// so you can review the proposed Step 3 UI without touching production routing.
library;

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'soil_onboarding_dropdown_mock_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SoilOnboardingUxMockApp());
}

/// Tiny MaterialApp that only hosts the soil onboarding mock screen.
class SoilOnboardingUxMockApp extends StatelessWidget {
  const SoilOnboardingUxMockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SoilGood — Soil onboarding UX mock',
      debugShowCheckedModeBanner: true,
      theme: AppTheme.light,
      home: const SoilOnboardingDropdownMockPage(),
    );
  }
}
