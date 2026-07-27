/// Onboarding step 3 screen — link the farmer's ESP32 by typing device_uid.
///
/// Last gate before AppShell. Skippable for now; saves into devices when claimed
/// so soil readings can be associated with this account.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/navigation/app_page_routes.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../auth/presentation/widgets/auth_error_banner.dart';
import '../../auth/presentation/widgets/auth_primary_button.dart';
import '../../auth/presentation/widgets/auth_text_field.dart';
import '../../shell/app_shell.dart';
import '../data/onboarding_repository.dart';

/// Onboarding Step 3 — claim ESP32 by typing `device_uid`.
class DeviceOnboardingPage extends StatefulWidget {
  const DeviceOnboardingPage({super.key});

  @override
  State<DeviceOnboardingPage> createState() => _DeviceOnboardingPageState();
}

class _DeviceOnboardingPageState extends State<DeviceOnboardingPage> {
  final _repo = OnboardingRepository();
  final _deviceUid = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _deviceUid.dispose();
    super.dispose();
  }

  /// Links the device then opens the main shell.
  Future<void> _claim() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await _repo.claimDevice(deviceUid: _deviceUid.text);
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(AppPageRoutes.slideFromRight(const AppShell()));
    } on Object catch (e) {
      setState(() {
        _error = e.toString();
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.primary,
        automaticallyImplyLeading: false,
        title: Text(
          'Link your sensor',
          style: GoogleFonts.literata(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          SoftCard(
            color: AppColors.primarySoft.withValues(alpha: 0.45),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Step 3 of 3',
                  style: TextStyle(
                    color: AppColors.primary.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Claim your ESP32',
                  style: GoogleFonts.literata(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Enter the device ID printed on your SoilGood sensor. '
                  'Without a device, the dashboard will show no live readings yet.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SoftCard(
            color: AppColors.surface,
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  AuthTextField(
                    controller: _deviceUid,
                    label: 'Device ID',
                    hint: 'SOILGOOD-XXXX',
                    icon: Icons.memory,
                    keyboardType: TextInputType.text,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  AuthErrorBanner(message: _error),
                  if (_error != null) const SizedBox(height: 12),
                  AuthPrimaryButton(
                    label: 'Link device',
                    isLoading: _saving,
                    onPressed: _claim,
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        AppPageRoutes.slideFromRight(const AppShell()),
                      );
                    },
                    child: const Text('Skip for now'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
