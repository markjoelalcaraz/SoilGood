/// Proposed onboarding Step 3 UI (texture + series as dropdowns) — preview only.
///
/// Opened only via [main_soil_onboarding_ux_mock.dart]. Does not save to
/// Supabase or navigate to device claim. Live production still uses
/// `SoilTextureOnboardingPage` radio cards until you ship this design.
///
/// Flow (matches scoring): series first (nothing pre-selected); texture
/// appears only for Not sure / Others. Others → Look up (mocked, no Groq).
/// DropdownMenu stays — not free-typed except the Others name box.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/soil/soil_series.dart';
import '../core/soil/soil_texture.dart';
import '../core/theme/app_colors.dart';
import '../features/auth/presentation/widgets/auth_primary_button.dart';
import '../features/auth/presentation/widgets/auth_text_field.dart';
import '../shared/widgets/app_content_width.dart';
import '../shared/widgets/ui_primitives.dart';

/// Fake Look-up result for Others (UX only — not a live AI call).
class _MockSeriesLookup {
  const _MockSeriesLookup({
    required this.summary,
    this.suggestedTexture,
    this.matchedSeries,
    this.notFound = false,
  });

  final String summary;
  final SoilTexture? suggestedTexture;
  final SoilSeries? matchedSeries;

  /// True when Look up found nothing useful — farmer must pick texture.
  final bool notFound;
}

/// Standalone mock of soil-type onboarding with compact dropdowns.
class SoilOnboardingDropdownMockPage extends StatefulWidget {
  const SoilOnboardingDropdownMockPage({super.key});

  @override
  State<SoilOnboardingDropdownMockPage> createState() =>
      _SoilOnboardingDropdownMockPageState();
}

class _SoilOnboardingDropdownMockPageState
    extends State<SoilOnboardingDropdownMockPage> {
  final _otherSeries = TextEditingController();
  late final TextEditingController _seriesMenuText;
  late final TextEditingController _textureMenuText;

  Key _textureMenuKey = UniqueKey();
  Key _seriesMenuKey = UniqueKey();

  /// null = nothing picked yet (not the same as Not sure).
  String? _seriesSelection;

  /// null until farmer picks (only shown on fallback path).
  SoilTexture? _texture;

  bool _lookupLoading = false;
  _MockSeriesLookup? _lookup;

  static const _skipWire = '__skip__';

  bool get _seriesChosen => _seriesSelection != null;

  /// Scoring fallback: explicit Not sure or Others (after a pick).
  bool get _needsTextureFallback =>
      _seriesSelection == _skipWire ||
      _seriesSelection == SoilSeries.other.wire;

  String get _seriesDisplayLabel {
    final sel = _seriesSelection;
    if (sel == null) return '';
    if (sel == _skipWire) return 'Not sure';
    return SoilSeries.fromWire(sel)?.label ?? '';
  }

  @override
  void initState() {
    super.initState();
    _seriesMenuText = TextEditingController();
    _textureMenuText = TextEditingController();
    _seriesMenuText.addListener(_lockSeriesMenuText);
    _textureMenuText.addListener(_lockTextureMenuText);
    _otherSeries.addListener(() {
      if (_lookup != null || _lookupLoading) {
        setState(() {
          _lookup = null;
          _lookupLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _seriesMenuText.removeListener(_lockSeriesMenuText);
    _textureMenuText.removeListener(_lockTextureMenuText);
    _seriesMenuText.dispose();
    _textureMenuText.dispose();
    _otherSeries.dispose();
    super.dispose();
  }

  void _lockSeriesMenuText() {
    final expected = _seriesDisplayLabel;
    if (_seriesMenuText.text == expected) return;
    _seriesMenuText.value = TextEditingValue(
      text: expected,
      selection: TextSelection.collapsed(offset: expected.length),
    );
  }

  void _lockTextureMenuText() {
    final expected = _texture?.label ?? '';
    if (_textureMenuText.text == expected) return;
    _textureMenuText.value = TextEditingValue(
      text: expected,
      selection: TextSelection.collapsed(offset: expected.length),
    );
  }

  /// Mock “AI” lookup: fuzzy curated match first, else name heuristics.
  Future<void> _lookUpOtherSeries() async {
    final name = _otherSeries.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a series name first.')),
      );
      return;
    }

    setState(() {
      _lookupLoading = true;
      _lookup = null;
    });

    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    final result = _mockLookup(name);
    setState(() {
      _lookupLoading = false;
      _lookup = result;
      // Not found → series becomes Not sure; match uses texture only.
      if (result.notFound) {
        _seriesSelection = _skipWire;
        _seriesMenuKey = UniqueKey();
        _seriesMenuText.text = 'Not sure';
        _otherSeries.clear();
        _texture = null;
        _textureMenuText.clear();
        _textureMenuKey = UniqueKey();
      }
    });
  }

  _MockSeriesLookup _mockLookup(String rawName) {
    final q = rawName.toLowerCase().trim();

    for (final s in SoilSeries.onboardingChoices) {
      if (s == SoilSeries.other) continue;
      final label = s.label.toLowerCase();
      if (q == label || q.contains(label) || label.contains(q)) {
        return _MockSeriesLookup(
          summary:
              'Looks like curated series “${s.label}”. Typical texture: '
              '${s.typicalTexture.label}.',
          suggestedTexture: s.typicalTexture == SoilTexture.unknown
              ? SoilTexture.loam
              : s.typicalTexture,
          matchedSeries: s,
        );
      }
    }

    // Weak keyword hints only (stand-in for Groq). No match → not found.
    if (q.contains('sand') || q.contains('buhangin')) {
      return _MockSeriesLookup(
        summary:
            'No curated series match for “$rawName”. '
            'Name hints at sandy soil — confirm below.',
        suggestedTexture: SoilTexture.sandy,
      );
    }
    if (q.contains('clay') || q.contains('putik')) {
      return _MockSeriesLookup(
        summary:
            'No curated series match for “$rawName”. '
            'Name hints at clay — confirm below.',
        suggestedTexture: SoilTexture.clay,
      );
    }
    if (q.contains('loam')) {
      return _MockSeriesLookup(
        summary:
            'No curated series match for “$rawName”. '
            'Name hints at loam — confirm below.',
        suggestedTexture: SoilTexture.loam,
      );
    }

    return _MockSeriesLookup(
      summary:
          'No match for “$rawName”. Soil series is set to Not sure — '
          'pick texture below. Crop match will use texture.',
      notFound: true,
    );
  }

  void _applyLookup() {
    final result = _lookup;
    if (result == null || result.notFound) return;

    setState(() {
      if (result.matchedSeries != null) {
        _seriesSelection = result.matchedSeries!.wire;
        _seriesMenuKey = UniqueKey();
        _seriesMenuText.text = result.matchedSeries!.label;
        _texture = null;
        _textureMenuText.clear();
        _textureMenuKey = UniqueKey();
        _lookup = null;
      } else if (result.suggestedTexture != null) {
        _texture = result.suggestedTexture;
        _textureMenuKey = UniqueKey();
        _textureMenuText.text = result.suggestedTexture!.label;
        _lookup = null;
      }
    });
  }

  void _onContinue() {
    if (!_seriesChosen) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a soil series (or Not sure).')),
      );
      return;
    }
    if (_seriesSelection == SoilSeries.other.wire &&
        _otherSeries.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the series name, or pick Not sure.')),
      );
      return;
    }
    if (_needsTextureFallback && _texture == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a texture (match fallback).')),
      );
      return;
    }

    final seriesLabel = _seriesSelection == _skipWire
        ? 'Not sure'
        : (_seriesSelection == SoilSeries.other.wire
            ? 'Others (${_otherSeries.text.trim()})'
            : SoilSeries.fromWire(_seriesSelection!)!.label);
    final texturePart = _needsTextureFallback
        ? _texture!.label
        : '(series used for match)';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Mock only — $seriesLabel · texture: $texturePart'),
      ),
    );
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
          'Soil type',
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
                    'Step 3 of 4 · UX MOCK',
                    style: TextStyle(
                      color: AppColors.primary.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'What soil is on your farm?',
                    style: GoogleFonts.literata(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Choose soil series first. If Not sure or Others, pick '
                    'texture — that is the match fallback.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SoftCard(
              color: AppColors.tertiarySoft.withValues(alpha: 0.65),
              child: const Text(
                'Isolated preview — dropdowns use in-app catalog (Dart enums), '
                'not a Supabase list table. Look up is mocked (no Groq).',
                style: TextStyle(
                  color: AppColors.tertiary,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Soil series',
              style: GoogleFonts.literata(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            LayoutBuilder(
              builder: (context, constraints) {
                return DropdownMenu<String>(
                  key: _seriesMenuKey,
                  width: constraints.maxWidth,
                  controller: _seriesMenuText,
                  hintText: 'Select…',
                  requestFocusOnTap: true,
                  enableFilter: false,
                  enableSearch: false,
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                  inputDecorationTheme: _menuDecorationTheme(),
                  menuStyle: _menuStyle(),
                  trailingIcon: const Icon(Icons.arrow_drop_down),
                  selectedTrailingIcon: const Icon(Icons.arrow_drop_up),
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'.')),
                  ],
                  onSelected: (wire) {
                    if (wire == null) return;
                    setState(() {
                      _seriesSelection = wire;
                      _seriesMenuKey = UniqueKey();
                      _seriesMenuText.text = _seriesDisplayLabel;
                      _lookup = null;
                      _lookupLoading = false;
                      if (!_needsTextureFallback) {
                        _texture = null;
                        _textureMenuText.clear();
                        _textureMenuKey = UniqueKey();
                      }
                    });
                  },
                  dropdownMenuEntries: [
                    const DropdownMenuEntry<String>(
                      value: _skipWire,
                      label: 'Not sure',
                    ),
                    for (final s in SoilSeries.onboardingChoices)
                      DropdownMenuEntry<String>(
                        value: s.wire,
                        label: s.label,
                      ),
                  ],
                );
              },
            ),
            if (_seriesChosen) ...[
              const SizedBox(height: 6),
              Text(
                _seriesSelection == _skipWire
                    ? 'No series ID — texture will be used for match'
                    : (_seriesSelection == SoilSeries.other.wire
                          ? 'Name it below — texture still used for match'
                          : 'Typical feel: ${SoilSeries.fromWire(_seriesSelection!)!.typicalTexture.label}'),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
            if (_seriesSelection == SoilSeries.other.wire) ...[
              const SizedBox(height: 12),
              SoftCard(
                color: AppColors.surface,
                child: AuthTextField(
                  controller: _otherSeries,
                  label: 'Series name',
                  hint: 'e.g. local / LGU name',
                  icon: Icons.edit_note,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _lookupLoading ? null : _lookUpOtherSeries,
                  icon: _lookupLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                  label: Text(_lookupLoading ? 'Looking up…' : 'Look up'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.45),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              if (_lookup != null && !_lookup!.notFound) ...[
                const SizedBox(height: 10),
                SoftCard(
                  color: AppColors.primarySoft.withValues(alpha: 0.45),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Look up result',
                        style: GoogleFonts.literata(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _lookup!.summary,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          height: 1.45,
                          fontSize: 13,
                        ),
                      ),
                      if (_lookup!.suggestedTexture != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Suggested texture: ${_lookup!.suggestedTexture!.label}',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: _applyLookup,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                              ),
                              child: Text(
                                _lookup!.matchedSeries != null
                                    ? 'Use ${_lookup!.matchedSeries!.label}'
                                    : 'Use texture',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () => setState(() => _lookup = null),
                            child: const Text('Dismiss'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
            // Not found: series already Not sure — text only, no buttons.
            if (_lookup?.notFound == true) ...[
              const SizedBox(height: 12),
              SoftCard(
                color: AppColors.errorContainer.withValues(alpha: 0.55),
                child: Text(
                  _lookup!.summary,
                  style: const TextStyle(
                    color: Color(0xFF690005),
                    height: 1.45,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            if (_needsTextureFallback) ...[
              const SizedBox(height: 16),
              Text(
                _lookup?.notFound == true
                    ? 'Texture (required — pick one)'
                    : 'Texture',
                style: GoogleFonts.literata(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: _lookup?.notFound == true
                      ? AppColors.error
                      : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              LayoutBuilder(
                builder: (context, constraints) {
                  return DropdownMenu<SoilTexture>(
                    key: _textureMenuKey,
                    width: constraints.maxWidth,
                    controller: _textureMenuText,
                    hintText: 'Select…',
                    requestFocusOnTap: true,
                    enableFilter: false,
                    enableSearch: false,
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                    inputDecorationTheme: _menuDecorationTheme(
                      emphasize: _lookup?.notFound == true,
                    ),
                    menuStyle: _menuStyle(),
                    trailingIcon: const Icon(Icons.arrow_drop_down),
                    selectedTrailingIcon: const Icon(Icons.arrow_drop_up),
                    inputFormatters: [
                      FilteringTextInputFormatter.deny(RegExp(r'.')),
                    ],
                    onSelected: (v) {
                      if (v == null) return;
                      setState(() {
                        _texture = v;
                        _textureMenuKey = UniqueKey();
                        _textureMenuText.text = v.label;
                        if (_lookup?.notFound == true) {
                          _lookup = null;
                        }
                      });
                    },
                    dropdownMenuEntries: [
                      for (final t in SoilTexture.onboardingChoices)
                        DropdownMenuEntry<SoilTexture>(
                          value: t,
                          label: t.label,
                        ),
                    ],
                  );
                },
              ),
              if (_texture != null) ...[
                const SizedBox(height: 6),
                Text(
                  _texture!.feelHint,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ],
            const SizedBox(height: 20),
            AuthPrimaryButton(
              label: 'Continue (mock)',
              isLoading: false,
              onPressed: _onContinue,
            ),
          ],
        ),
      ),
    );
  }

  InputDecorationTheme _menuDecorationTheme({bool emphasize = false}) {
    final borderColor = emphasize
        ? AppColors.error.withValues(alpha: 0.55)
        : AppColors.outline.withValues(alpha: 0.55);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: borderColor),
    );
    return InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: emphasize
              ? AppColors.error.withValues(alpha: 0.75)
              : AppColors.primary.withValues(alpha: 0.55),
          width: 1.5,
        ),
      ),
    );
  }

  MenuStyle _menuStyle() {
    return MenuStyle(
      backgroundColor: const WidgetStatePropertyAll(AppColors.surface),
      elevation: const WidgetStatePropertyAll(6),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      maximumSize: WidgetStatePropertyAll(
        Size(double.infinity, MediaQuery.sizeOf(context).height * 0.45),
      ),
    );
  }
}
