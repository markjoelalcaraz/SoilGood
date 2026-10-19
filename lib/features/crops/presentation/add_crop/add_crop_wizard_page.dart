/// Pushed "Add a crop" wizard, outside the app shell (opened from Home's crop
/// picker and the Farm tab's "+ Add crop").
///
/// A new plot has no data yet, so this asks about the plot first: soil type
/// (BSWM series, optional), soil texture only when the series is unknown (same
/// fallback as onboarding), then the required sensor in that soil. It waits for
/// that sensor's first fresh reading, then opens [CropsPage] so the matches use
/// this plot's own soil and sensor. Pops `true` once a crop is planted.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/soil/soil_series.dart';
import '../../../../core/soil/soil_texture.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/data/refresh_timeout.dart';
import '../../../../shared/navigation/app_page_routes.dart';
import '../../../../shared/widgets/app_content_width.dart';
import '../../../../shared/widgets/ui_primitives.dart';
import '../../../auth/presentation/widgets/auth_error_banner.dart';
import '../../../auth/presentation/widgets/auth_primary_button.dart';
import '../../../auth/presentation/widgets/auth_text_field.dart';
import '../../../farm/data/farm_sensor.dart';
import '../../../farm/data/plot_sensors_repository.dart';
import '../../../home/data/soil_reading.dart';
import '../../../onboarding/logic/device_claim_rules.dart';
import '../../../weather/data/farm_location_repository.dart';
import '../../data/plot_draft.dart';
import '../crops_page.dart';
import 'plot_choice_tile.dart';

/// Readings this old (before the farmer confirmed the sensor) still count as
/// "in this soil" — about one ESP32 cycle, so a kit already in the ground
/// does not force a full wait.
const kFreshReadingWindow = Duration(minutes: 20);

enum _Step { series, texture, sensor, waiting }

/// Soil type → (texture) → sensor → first reading → crop matches.
class AddCropWizardPage extends StatefulWidget {
  const AddCropWizardPage({super.key});

  @override
  State<AddCropWizardPage> createState() => _AddCropWizardPageState();
}

class _AddCropWizardPageState extends State<AddCropWizardPage> {
  final _farms = FarmLocationRepository();
  final _sensorsRepo = PlotSensorsRepository();
  final _otherName = TextEditingController();
  final _code = TextEditingController();

  bool _loading = true;
  bool _defaultsApplied = false;
  Object? _loadError;
  SoilSeries? _farmSeries;
  SoilTexture? _farmTexture;
  List<FarmSensor> _sensors = [];

  _Step _step = _Step.series;

  /// True = "Not sure" (no series). Texture becomes the match input.
  bool _seriesNotSure = true;
  SoilSeries? _series;
  SoilTexture? _texture;

  String? _pickedDeviceId;
  bool _claiming = false;
  String? _stepError;

  String? _deviceId;
  String? _claimCode;
  DateTime? _since;
  StreamSubscription<SoilReading?>? _readingSub;
  SoilReading? _reading;
  bool _checking = false;
  Object? _waitError;
  bool _matchesOpen = false;

  @override
  void initState() {
    super.initState();
    _loadFarm();
  }

  @override
  void dispose() {
    unawaited(_readingSub?.cancel() ?? Future.value());
    _otherName.dispose();
    _code.dispose();
    super.dispose();
  }

  /// Farm soil (defaults for step 1–2) and every kit on the farm (step 3).
  ///
  /// Pull reloads the kit list but never overwrites what the farmer picked.
  Future<void> _loadFarm() async {
    try {
      final farmId = await withRefreshTimeout(_farms.getPrimaryFarmId());
      if (farmId == null) {
        throw StateError('No farm found. Finish onboarding first.');
      }
      final series = await withRefreshTimeout(_farms.getPrimaryFarmSoilSeries());
      final texture = await withRefreshTimeout(
        _farms.getPrimaryFarmSoilTexture(),
      );
      final sensors = await withRefreshTimeout(
        _sensorsRepo.listForFarm(farmId),
      );
      if (!mounted) return;
      setState(() {
        _farmSeries = series;
        _farmTexture = texture;
        _sensors = sensors;
        _loadError = null;
        _loading = false;
        if (!_defaultsApplied) {
          _defaultsApplied = true;
          _series = series;
          _seriesNotSure = series == null;
          _texture = texture;
        }
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e;
        _loading = false;
      });
    }
  }

  /// Texture is asked only when the series cannot stand in for it.
  bool get _needsTexture => _seriesNotSure || _series == SoilSeries.other;

  /// Texture saved on the plot: picked, or the series' typical feel.
  SoilTexture? get _plotTexture =>
      _needsTexture ? _texture : _series?.typicalTexture;

  List<_Step> get _flow => [
    _Step.series,
    if (_needsTexture) _Step.texture,
    _Step.sensor,
    _Step.waiting,
  ];

  void _goTo(_Step step) => setState(() {
    _step = step;
    _stepError = null;
  });

  /// App bar / system back walks the wizard backwards before leaving.
  void _back() {
    final i = _flow.indexOf(_step);
    if (i <= 0) {
      Navigator.of(context).pop(false);
      return;
    }
    if (_step == _Step.waiting) {
      unawaited(_readingSub?.cancel() ?? Future.value());
      _readingSub = null;
    }
    _goTo(_flow[i - 1]);
  }

  void _seriesNext() {
    if (!_seriesNotSure &&
        _series == SoilSeries.other &&
        _otherName.text.trim().isEmpty) {
      setState(
        () => _stepError = 'Type the soil series name, or choose Not sure.',
      );
      return;
    }
    _goTo(_needsTexture ? _Step.texture : _Step.sensor);
  }

  void _textureNext() {
    if (_texture == null) {
      setState(() => _stepError = 'Choose how the soil feels.');
      return;
    }
    _goTo(_Step.sensor);
  }

  /// Typed code wins over a picked kit. New codes are claimed onto the farm.
  Future<void> _sensorNext() async {
    final typed = normalizeClaimCode(_code.text);
    setState(() {
      _claiming = true;
      _stepError = null;
    });
    try {
      String deviceId;
      String code;
      if (typed != null) {
        final known = _sensors.where((s) => s.claimCode == typed).firstOrNull;
        if (known != null) {
          if (known.onActivePlot) {
            throw StateError(
              '${known.label} is already on ${known.cropName}. '
              'Use another sensor for this plot.',
            );
          }
          deviceId = known.id;
        } else {
          deviceId = await _sensorsRepo.claimToFarm(typed);
        }
        code = typed;
      } else {
        final picked = _sensors.where((s) => s.id == _pickedDeviceId).firstOrNull;
        if (picked == null) {
          throw StateError(
            'Type the code on the sensor sticker, or pick a sensor below.',
          );
        }
        deviceId = picked.id;
        code = picked.claimCode;
      }
      if (!mounted) return;
      setState(() => _claiming = false);
      _startWaiting(deviceId: deviceId, code: code);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _claiming = false;
        _stepError = e is StateError ? e.message : '$e';
      });
    }
  }

  /// Listens live for the sensor's first fresh reading, plus one fetch now.
  void _startWaiting({required String deviceId, required String code}) {
    final since = DateTime.now().subtract(kFreshReadingWindow);
    unawaited(_readingSub?.cancel() ?? Future.value());
    setState(() {
      _deviceId = deviceId;
      _claimCode = code;
      _since = since;
      _reading = null;
      _waitError = null;
      _matchesOpen = false;
      _step = _Step.waiting;
      _stepError = null;
    });
    _readingSub = _sensorsRepo
        .watchReadingSince(deviceId: deviceId, since: since)
        .listen(
          _onReading,
          onError: (Object e) {
            if (mounted) setState(() => _waitError = e);
          },
        );
    unawaited(_checkNow());
  }

  /// Pull / "Check now": one fetch, in case Realtime is slow on weak signal.
  Future<void> _checkNow() async {
    final deviceId = _deviceId;
    final since = _since;
    if (deviceId == null || since == null) return;
    setState(() => _checking = true);
    try {
      final reading = await withRefreshTimeout(
        _sensorsRepo.fetchReadingSince(deviceId: deviceId, since: since),
      );
      if (!mounted) return;
      setState(() {
        _checking = false;
        _waitError = null;
      });
      _onReading(reading);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _waitError = e;
      });
    }
  }

  void _onReading(SoilReading? reading) {
    if (!mounted || reading == null || _step != _Step.waiting) return;
    final first = _reading == null;
    setState(() => _reading = reading);
    if (first) unawaited(_openMatches());
  }

  /// Crop matches for this plot. Planting there closes the wizard too.
  Future<void> _openMatches() async {
    final reading = _reading;
    final texture = _plotTexture;
    final deviceId = _deviceId;
    final code = _claimCode;
    if (reading == null || texture == null || deviceId == null || code == null) {
      return;
    }
    if (_matchesOpen) return;
    _matchesOpen = true;
    final plot = PlotDraft(
      texture: texture,
      series: _seriesNotSure ? null : _series,
      seriesOther: _series == SoilSeries.other ? _otherName.text.trim() : null,
      deviceId: deviceId,
      claimCode: code,
      reading: reading,
    );
    final planted = await Navigator.of(context).push<bool>(
      AppPageRoutes.slideFromRight(CropsPage(plot: plot)),
    );
    if (!mounted) return;
    if (planted == true) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _matchesOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final flow = _flow;
    final index = flow.indexOf(_step);
    // "Step x of y" counts the questions; waiting shares the sensor step.
    final questionCount = flow.length - 1;
    final stepNumber = (index + 1).clamp(1, questionCount);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.primary,
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back),
            onPressed: _back,
          ),
          title: Text(
            'Add a crop',
            style: GoogleFonts.literata(fontWeight: FontWeight.w700),
          ),
        ),
        body: SafeArea(
          child: AppContentWidth(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _step == _Step.waiting ? _checkNow : _loadFarm,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
                  _ProgressBar(current: stepNumber, total: questionCount),
                  const SizedBox(height: 16),
                  if (_loadError != null) ...[
                    AuthErrorBanner(message: 'Could not load your farm:\n$_loadError'),
                    const SizedBox(height: 12),
                  ],
                  if (_loading)
                    const SoftCard(
                      color: AppColors.surfaceMuted,
                      child: SizedBox(height: 260),
                    )
                  else
                    ..._stepBody(stepNumber, questionCount),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _stepBody(int number, int total) {
    switch (_step) {
      case _Step.series:
        return _seriesStep(number, total);
      case _Step.texture:
        return _textureStep(number, total);
      case _Step.sensor:
        return _sensorStep(number, total);
      case _Step.waiting:
        return _waitingStep();
    }
  }

  List<Widget> _seriesStep(int number, int total) {
    return [
      _StepHeader(
        label: 'Step $number of $total · Soil type',
        question: 'What soil type is this plot?',
        hint: 'If you know the soil series, crop match uses it. '
            'Not sure? We will ask how the soil feels instead.',
      ),
      const SizedBox(height: 16),
      PlotChoiceTile(
        title: 'Not sure',
        subtitle: 'We will use the soil texture for crop match',
        selected: _seriesNotSure,
        tag: _farmSeries == null && _defaultsApplied ? 'Same as your farm' : null,
        onTap: () => setState(() {
          _seriesNotSure = true;
          _series = null;
          _stepError = null;
        }),
      ),
      for (final s in SoilSeries.onboardingChoices)
        PlotChoiceTile(
          title: s.label,
          subtitle: s.typicalTexture == SoilTexture.unknown
              ? s.hint
              : 'Typical feel: ${s.typicalTexture.label}. ${s.hint}',
          selected: !_seriesNotSure && _series == s,
          tag: s == _farmSeries ? 'Same as your farm' : null,
          onTap: () => setState(() {
            _seriesNotSure = false;
            _series = s;
            _stepError = null;
          }),
        ),
      if (!_seriesNotSure && _series == SoilSeries.other) ...[
        const SizedBox(height: 4),
        SoftCard(
          color: AppColors.surface,
          child: AuthTextField(
            controller: _otherName,
            label: 'Series name',
            hint: 'e.g. local or LGU name',
            icon: Icons.edit_note,
          ),
        ),
      ],
      ..._footer(label: 'Next', onPressed: _seriesNext),
    ];
  }

  List<Widget> _textureStep(int number, int total) {
    final suggestedByFarm = _farmTexture;
    return [
      _StepHeader(
        label: 'Step $number of $total · Soil texture',
        question: 'How does the soil feel?',
        hint: 'Wet a small lump and rub it between your fingers.',
      ),
      const SizedBox(height: 16),
      for (final t in SoilTexture.onboardingChoices)
        PlotChoiceTile(
          title: t.label,
          subtitle: t.feelHint,
          selected: _texture == t,
          tag: t == suggestedByFarm ? 'Same as your farm' : null,
          onTap: () => setState(() {
            _texture = t;
            _stepError = null;
          }),
        ),
      ..._footer(label: 'Next', onPressed: _textureNext),
    ];
  }

  List<Widget> _sensorStep(int number, int total) {
    final free = [
      for (final s in _sensors)
        if (!s.onActivePlot) s,
    ];
    final busy = [
      for (final s in _sensors)
        if (s.onActivePlot) s,
    ];
    return [
      _StepHeader(
        label: 'Step $number of $total · Sensor',
        question: 'Which sensor is in this soil?',
        hint: 'A sensor is required. Its readings decide which crops fit this plot.',
      ),
      const SizedBox(height: 16),
      const _SectionLabel('TYPE THE CODE ON THE STICKER'),
      const SizedBox(height: 8),
      SoftCard(
        color: AppColors.surface,
        child: AuthTextField(
          controller: _code,
          label: 'Claim code',
          hint: 'SG-XXXX',
          icon: Icons.qr_code_2,
          onChanged: (_) => setState(() {
            _pickedDeviceId = null;
            _stepError = null;
          }),
        ),
      ),
      if (free.isNotEmpty || busy.isNotEmpty) ...[
        const SizedBox(height: 16),
        const _SectionLabel('OR PICK A SENSOR ON YOUR FARM'),
        const SizedBox(height: 8),
        for (final s in free)
          PlotChoiceTile(
            leading: const Icon(Icons.sensors, color: AppColors.navIcon),
            title: s.label,
            subtitle: 'Not on a plot yet',
            selected: _pickedDeviceId == s.id && _code.text.trim().isEmpty,
            onTap: () => setState(() {
              _code.clear();
              _pickedDeviceId = s.id;
              _stepError = null;
            }),
          ),
        for (final s in busy)
          PlotChoiceTile(
            leading: const Icon(Icons.sensors, color: AppColors.textSecondary),
            title: s.label,
            subtitle: 'Already on ${s.cropName}',
            selected: false,
            onTap: null,
          ),
      ],
      ..._footer(
        label: 'Use this sensor',
        onPressed: _claiming ? null : _sensorNext,
        loading: _claiming,
      ),
    ];
  }

  List<Widget> _waitingStep() {
    final texture = _plotTexture;
    final seriesLabel = _seriesNotSure
        ? 'Not sure'
        : _series == SoilSeries.other
        ? (_otherName.text.trim().isEmpty ? 'Others' : _otherName.text.trim())
        : _series!.label;
    final code = _claimCode ?? '';
    final got = _reading != null;

    return [
      SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionLabel('THIS PLOT'),
            const SizedBox(height: 8),
            _SummaryRow(label: 'Soil type', value: seriesLabel),
            _SummaryRow(label: 'Texture', value: texture?.label ?? '—'),
            _SummaryRow(label: 'Sensor', value: code),
          ],
        ),
      ),
      const SizedBox(height: 12),
      SoftCard(
        child: Column(
          children: [
            const SizedBox(height: 8),
            if (got)
              const Icon(Icons.check_circle, color: AppColors.primary, size: 56)
            else
              const SizedBox(
                width: 56,
                height: 56,
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 5,
                ),
              ),
            const SizedBox(height: 16),
            Text(
              got ? 'Reading received' : 'Waiting for the first reading',
              textAlign: TextAlign.center,
              style: GoogleFonts.literata(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              got
                  ? 'Sensor ($code) sent soil data from this plot. '
                        'See which crops fit it.'
                  : 'Sensor ($code) usually sends one within 15 minutes. '
                        'Crop matches open on their own when it arrives.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.45,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (!got) ...[
              const SizedBox(height: 8),
              const Text(
                'You can leave. Next time, pick this sensor again in Add a crop.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, height: 1.45),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
      if (_waitError != null) ...[
        const SizedBox(height: 12),
        AuthErrorBanner(message: 'Could not check the sensor:\n$_waitError'),
      ],
      const SizedBox(height: 16),
      if (got)
        AuthPrimaryButton(
          label: 'See crops for this plot',
          isLoading: false,
          onPressed: _openMatches,
        )
      else ...[
        SizedBox(
          height: 48,
          child: OutlinedButton(
            onPressed: _checking ? null : _checkNow,
            child: Text(_checking ? 'Checking…' : 'Check now'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("I'll come back later"),
          ),
        ),
      ],
    ];
  }

  /// Error banner + primary action at the end of the scroll (keyboard-safe).
  List<Widget> _footer({
    required String label,
    required VoidCallback? onPressed,
    bool loading = false,
  }) {
    return [
      if (_stepError != null) ...[
        const SizedBox(height: 8),
        AuthErrorBanner(message: _stepError),
      ],
      const SizedBox(height: 16),
      AuthPrimaryButton(label: label, isLoading: loading, onPressed: onPressed),
    ];
  }
}

/// Thin segmented bar across the top of each step.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Container(
              height: 5,
              decoration: BoxDecoration(
                color: i < current ? AppColors.buttonGreen : AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({
    required this.label,
    required this.question,
    required this.hint,
  });

  final String label;
  final String question;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      color: AppColors.primarySoft.withValues(alpha: 0.45),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.primary.withValues(alpha: 0.9),
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            question,
            style: GoogleFonts.literata(
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hint,
            style: const TextStyle(color: AppColors.textSecondary, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.navIcon,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
        fontSize: 12,
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
