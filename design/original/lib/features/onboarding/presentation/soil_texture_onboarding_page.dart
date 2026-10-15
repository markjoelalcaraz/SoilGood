/// Onboarding step 3 screen — required soil texture + optional soil series.
///
/// Shown after farm location and before device claim. Saves texture always;
/// curated series is optional (Skip). When series is curated, crop match uses
/// series fit and ignores texture. Research: SOIL_SERIES_CROP_FIT.md.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/soil/soil_series.dart';
import '../../../core/soil/soil_texture.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/navigation/app_page_routes.dart';
import '../../../shared/widgets/app_content_width.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../auth/presentation/widgets/auth_error_banner.dart';
import '../../auth/presentation/widgets/auth_primary_button.dart';
import '../../auth/presentation/widgets/auth_text_field.dart';
import '../data/onboarding_repository.dart';
import 'device_onboarding_page.dart';

/// Onboarding Step 3 — texture required; series optional under it.
class SoilTextureOnboardingPage extends StatefulWidget {
  const SoilTextureOnboardingPage({super.key});

  @override
  State<SoilTextureOnboardingPage> createState() =>
      _SoilTextureOnboardingPageState();
}

class _SoilTextureOnboardingPageState extends State<SoilTextureOnboardingPage> {
  final _repo = OnboardingRepository();
  final _otherSeries = TextEditingController();

  SoilTexture? _selectedTexture;

  /// null = Skip (no series). Otherwise curated or Other.
  SoilSeries? _selectedSeries;
  bool _seriesSkipped = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _otherSeries.dispose();
    super.dispose();
  }

  /// Persists texture + optional series then opens device claim.
  Future<void> _continue() async {
    final texture = _selectedTexture;
    if (texture == null) {
      setState(() => _error = 'Piliin ang uri ng lupa (texture) sa farm mo.');
      return;
    }

    if (!_seriesSkipped &&
        _selectedSeries == SoilSeries.other &&
        _otherSeries.text.trim().isEmpty) {
      setState(
        () => _error = 'Ilagay ang pangalan ng soil series, o piliin Skip.',
      );
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await _repo.saveSoilPhysicalProfile(
        texture: texture,
        series: _seriesSkipped ? null : _selectedSeries,
        seriesOther: _seriesSkipped ? null : _otherSeries.text,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        AppPageRoutes.slideFromRight(const DeviceOnboardingPage()),
      );
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
          'Uri ng lupa',
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
                    'Step 3 of 4',
                    style: TextStyle(
                      color: AppColors.primary.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Anong klaseng lupa ang farm mo?',
                    style: GoogleFonts.literata(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Texture (required): damhin ang lupa. Soil series (optional): '
                    'kung alam mo ang BSWM/PhilRice name — iyon ang gagamitin sa '
                    'crop match imbes na texture.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              AuthErrorBanner(message: _error),
            ],
            const SizedBox(height: 16),
            Text(
              'Texture (required)',
              style: GoogleFonts.literata(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            ...SoilTexture.onboardingChoices.map(_textureTile),
            const SizedBox(height: 20),
            Text(
              'Soil series (optional)',
              style: GoogleFonts.literata(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Skip kung hindi mo sure. Typical feel = hint lang, hindi '
              'papalitan ang texture pick mo.',
              style: TextStyle(
                color: AppColors.textSecondary,
                height: 1.4,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 10),
            _seriesChoiceTile(
              selected: _seriesSkipped,
              title: 'Not sure',
              subtitle: 'Texture is used for crop match',
              onTap: () => setState(() {
                _seriesSkipped = true;
                _selectedSeries = null;
                _error = null;
              }),
            ),
            ...SoilSeries.onboardingChoices.map(_seriesTile),
            if (!_seriesSkipped && _selectedSeries == SoilSeries.other) ...[
              const SizedBox(height: 8),
              SoftCard(
                color: AppColors.surface,
                child: AuthTextField(
                  controller: _otherSeries,
                  label: 'Pangalan ng series',
                  hint: 'Hal. local / LGU name',
                  icon: Icons.edit_note,
                ),
              ),
            ],
            const SizedBox(height: 20),
            AuthPrimaryButton(
              label: 'Continue',
              isLoading: _saving,
              onPressed: _saving ? null : _continue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _textureTile(SoilTexture texture) {
    final selected = _selectedTexture == texture;
    return _radioCard(
      selected: selected,
      title: texture.label,
      subtitle: texture.feelHint,
      onTap: () => setState(() {
        _selectedTexture = texture;
        _error = null;
      }),
    );
  }

  Widget _seriesTile(SoilSeries series) {
    final selected = !_seriesSkipped && _selectedSeries == series;
    final typical = series.typicalTexture;
    final typicalNote = typical == SoilTexture.unknown
        ? series.hint
        : 'Typical feel: ${typical.label}. ${series.hint}';
    return _radioCard(
      selected: selected,
      title: series.label,
      subtitle: typicalNote,
      onTap: () => setState(() {
        _seriesSkipped = false;
        _selectedSeries = series;
        _error = null;
      }),
    );
  }

  Widget _seriesChoiceTile({
    required bool selected,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return _radioCard(
      selected: selected,
      title: title,
      subtitle: subtitle,
      onTap: onTap,
    );
  }

  /// Shared selectable row for texture / series.
  Widget _radioCard({
    required bool selected,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected
            ? AppColors.primarySoft.withValues(alpha: 0.55)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _saving ? null : onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.45)
                    : AppColors.outline.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.literata(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          height: 1.4,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
