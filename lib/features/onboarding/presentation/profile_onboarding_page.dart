/// Onboarding step 1 screen — collect farmer name/address before the app shell.
///
/// Shown by AuthGate when the profile is incomplete. Saves to profiles, then
/// continues to the farm location step (or pops when opened from Profile edit).
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
import '../data/onboarding_repository.dart';
import 'location_onboarding_page.dart';

/// Onboarding Step 1 — save profile to Supabase, then go to GPS map step.
class ProfileOnboardingPage extends StatefulWidget {
  const ProfileOnboardingPage({this.fromProfile = false, super.key});

  /// When true, opened from Profile tab — pop after save.
  final bool fromProfile;

  @override
  State<ProfileOnboardingPage> createState() => _ProfileOnboardingPageState();
}

class _ProfileOnboardingPageState extends State<ProfileOnboardingPage> {
  final _repo = OnboardingRepository();
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _barangay = TextEditingController();
  final _city = TextEditingController();
  final _province = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  /// Prefills fields from an existing profile row when available.
  Future<void> _prefill() async {
    try {
      final profile = await _repo.loadProfile();
      if (profile != null && mounted) {
        _firstName.text = (profile['first_name'] as String?) ?? '';
        _lastName.text = (profile['last_name'] as String?) ?? '';
        _barangay.text = (profile['barangay'] as String?) ?? '';
        _city.text = (profile['municipality_city'] as String?) ?? '';
        _province.text = (profile['province'] as String?) ?? '';
      }
    } on Object catch (e) {
      _error = 'Could not load profile: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Writes profile to Supabase then continues the onboarding flow.
  Future<void> _continue() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await _repo.saveProfile(
        firstName: _firstName.text,
        lastName: _lastName.text,
        barangay: _barangay.text,
        municipalityCity: _city.text,
        province: _province.text,
      );

      if (!mounted) return;
      if (widget.fromProfile) {
        Navigator.of(context).pop();
        return;
      }

      Navigator.of(context).pushReplacement(
        AppPageRoutes.slideFromRight(const LocationOnboardingPage()),
      );
    } on Object catch (e) {
      setState(() {
        _error = 'Could not save profile: $e';
        _saving = false;
      });
    }
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _barangay.dispose();
    _city.dispose();
    _province.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.primary,
        automaticallyImplyLeading: widget.fromProfile,
        title: Text(
          widget.fromProfile ? 'Edit Profile' : 'Set up your profile',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.literata(fontWeight: FontWeight.w700),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: AppContentWidth(
                child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
                  SoftCard(
                    color: AppColors.primarySoft.withValues(alpha: 0.45),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Step 1 of 3',
                          style: TextStyle(
                            color: AppColors.primary.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Tell us who you are',
                          style: GoogleFonts.literata(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Next: farm location (GPS + map pin), then link your ESP32.',
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
                            controller: _firstName,
                            label: 'First name',
                            hint: 'Juan',
                            icon: Icons.badge_outlined,
                            keyboardType: TextInputType.name,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Required'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          AuthTextField(
                            controller: _lastName,
                            label: 'Last name',
                            hint: 'Dela Cruz',
                            icon: Icons.badge_outlined,
                            keyboardType: TextInputType.name,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Required'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          AuthTextField(
                            controller: _barangay,
                            label: 'Barangay',
                            hint: 'San Isidro',
                            icon: Icons.home_outlined,
                            keyboardType: TextInputType.streetAddress,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Required'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          AuthTextField(
                            controller: _city,
                            label: 'Municipality / City',
                            hint: 'Santa Rosa',
                            icon: Icons.location_city_outlined,
                            keyboardType: TextInputType.streetAddress,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Required'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          AuthTextField(
                            controller: _province,
                            label: 'Province',
                            hint: 'Laguna',
                            icon: Icons.map_outlined,
                            keyboardType: TextInputType.streetAddress,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Required'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          AuthErrorBanner(message: _error),
                          if (_error != null) const SizedBox(height: 12),
                          AuthPrimaryButton(
                            label: widget.fromProfile
                                ? 'Save profile'
                                : 'Continue',
                            isLoading: _saving,
                            onPressed: _continue,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}
