/// Onboarding step 3 screen — link the farmer's ESP32 by typing a claim code.
///
/// Last gate before AppShell. Skippable for UI testing. Lab pre-provisions the
/// kit; the farmer types the sticker code (never sees ingest_token).
/// Optional [claimDevice] / [onClaimSuccess] let critical E2E inject fakes
/// without hitting Supabase.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/navigation/app_page_routes.dart';
import '../../../shared/widgets/app_content_width.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../auth/presentation/widgets/auth_error_banner.dart';
import '../../auth/presentation/widgets/auth_primary_button.dart';
import '../../auth/presentation/widgets/auth_text_field.dart';
import '../../shell/app_shell.dart';
import '../data/onboarding_repository.dart';

/// Onboarding Step 3 — claim ESP32 by typing sticker `claim_code`.
class DeviceOnboardingPage extends StatefulWidget {
  const DeviceOnboardingPage({
    super.key,
    this.claimDevice,
    this.onClaimSuccess,
    this.showSkip = true,
  });

  /// When set, used instead of [OnboardingRepository.claimDevice] (E2E / tests).
  final Future<void> Function({required String claimCode})? claimDevice;

  /// When set, called after a successful claim instead of opening [AppShell].
  final VoidCallback? onClaimSuccess;

  /// Production shows Skip; E2E claim-only flows can hide it.
  final bool showSkip;

  @override
  State<DeviceOnboardingPage> createState() => _DeviceOnboardingPageState();
}

class _DeviceOnboardingPageState extends State<DeviceOnboardingPage> {
  final _repo = OnboardingRepository();
  final _claimCode = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _claimCode.dispose();
    super.dispose();
  }

  /// Calls claim_device then opens the main shell (or [onClaimSuccess]).
  Future<void> _claim() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final claim = widget.claimDevice ?? _repo.claimDevice;
      await claim(claimCode: _claimCode.text);
      if (!mounted) return;
      if (widget.onClaimSuccess != null) {
        widget.onClaimSuccess!();
        return;
      }
      Navigator.of(
        context,
      ).pushReplacement(AppPageRoutes.slideFromRight(const AppShell()));
    } on Object catch (e) {
      setState(() {
        _error = e is StateError ? e.message : e.toString();
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
      body: AppContentWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            SoftCard(
              color: AppColors.primarySoft.withValues(alpha: 0.45),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Step 4 of 4',
                    style: TextStyle(
                      color: AppColors.primary.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ilagay ang code sa box',
                    style: GoogleFonts.literata(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Type the claim code written on your SoilGood kit '
                    '(hal. SG-7K2M). Without a linked sensor, Home will have '
                    'no live readings yet.',
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
                      key: const Key('e2e_claim_code_field'),
                      controller: _claimCode,
                      label: 'Claim code',
                      hint: 'SG-XXXX',
                      icon: Icons.qr_code_2,
                      keyboardType: TextInputType.text,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    AuthErrorBanner(
                      key: const Key('e2e_claim_error_banner'),
                      message: _error,
                    ),
                    if (_error != null) const SizedBox(height: 12),
                    AuthPrimaryButton(
                      key: const Key('e2e_link_sensor_button'),
                      label: 'Link sensor',
                      isLoading: _saving,
                      onPressed: _claim,
                    ),
                    if (widget.showSkip)
                      TextButton(
                        key: const Key('e2e_claim_skip_button'),
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
      ),
    );
  }
}
