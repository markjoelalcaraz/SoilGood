/// Critical E2E harness — claim → live soil truth → offline alert (no Supabase).
///
/// Driven by `integration_test/critical_flows_e2e_test.dart`. Uses the real
/// [DeviceOnboardingPage] UI plus a thin Home/alert panel so taps exercise
/// farmer-facing screens without network. Not a production entrypoint.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../features/home/data/soil_reading.dart';
import '../features/home/logic/live_soil_truth.dart';
import '../features/notifications/data/farm_notification.dart';
import '../features/notifications/logic/notification_evaluator.dart';
import '../features/onboarding/logic/device_claim_rules.dart';
import '../features/onboarding/presentation/device_onboarding_page.dart';
import '../shared/widgets/app_content_width.dart';
import '../shared/widgets/ui_primitives.dart';

/// Valid sticker used by TC_DEVICE_001 happy path.
const String kE2eValidClaimCode = 'SG-7K2M';

/// Already-used sticker for TC_DEVICE_002.
const String kE2eUsedClaimCode = 'SG-USED1';

/// Fake claim RPC: valid code succeeds; used/unknown throw farmer messages.
Future<void> fakeClaimDevice({required String claimCode}) async {
  final code = normalizeClaimCode(claimCode);
  if (code == null) {
    throw StateError(kEmptyClaimCodeMessage);
  }
  await Future<void>.delayed(const Duration(milliseconds: 20));
  if (code == kE2eValidClaimCode) return;
  if (code == kE2eUsedClaimCode) {
    throw StateError('This claim code was already used');
  }
  throw StateError('Claim code not found. Check the code on your box');
}

/// Stateful host: claim page → critical Home soil + alert strip.
class CriticalE2eHost extends StatefulWidget {
  const CriticalE2eHost({
    super.key,
    this.now,
    this.homeReadings,
    this.startOnHome = false,
    this.fetchFailed = false,
  });

  final DateTime? now;
  final List<SoilReading>? homeReadings;
  final bool startOnHome;
  final bool fetchFailed;

  @override
  State<CriticalE2eHost> createState() => _CriticalE2eHostState();
}

class _CriticalE2eHostState extends State<CriticalE2eHost> {
  late bool _claimed;

  DateTime get _now => widget.now ?? DateTime.utc(2026, 9, 17, 12, 0, 0);

  List<SoilReading> get _readings =>
      widget.homeReadings ??
      [
        SoilReading(
          id: 'old',
          recordedAt: _now.subtract(const Duration(hours: 3)),
          moisturePercent: 20,
          ph: 6.0,
        ),
        SoilReading(
          id: 'new',
          recordedAt: _now.subtract(const Duration(minutes: 5)),
          moisturePercent: 42,
          ph: 6.4,
        ),
      ];

  @override
  void initState() {
    super.initState();
    _claimed = widget.startOnHome;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SoilGood Critical E2E',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: _claimed
          ? CriticalLiveSoilPage(
              now: _now,
              readings: _readings,
              fetchFailed: widget.fetchFailed,
            )
          : DeviceOnboardingPage(
              showSkip: false,
              claimDevice: fakeClaimDevice,
              onClaimSuccess: () => setState(() => _claimed = true),
            ),
    );
  }
}

/// Thin Home-truth panel for E2E (latest moisture + live/stale/empty/error).
class CriticalLiveSoilPage extends StatelessWidget {
  const CriticalLiveSoilPage({
    super.key,
    required this.now,
    required this.readings,
    this.fetchFailed = false,
  });

  final DateTime now;
  final List<SoilReading> readings;
  final bool fetchFailed;

  @override
  Widget build(BuildContext context) {
    final latest = pickLatestReading(readings);
    final kind = classifyLiveSoilTruth(
      fetchFailed: fetchFailed,
      latest: latest,
      now: now,
    );

    final drafts = latest == null
        ? <NotificationDraft>[]
        : const NotificationEvaluator().evaluate(
            farmId: 'e2e-farm',
            reading: latest,
            facts: const {
              'moisture': 'ok',
              'n_band': 'ok',
              'p_band': 'ok',
              'k_band': 'ok',
              'ph_band': 'ok',
              'temp_band': 'ok',
              'ec_band': 'ok',
              'salinity_band': 'ok',
            },
            now: now,
          );
    final offline = drafts.where(
      (d) => d.type == FarmNotificationType.deviceOffline,
    );

    final moistureLabel = latest?.moisturePercent == null
        ? '—'
        : '${latest!.moisturePercent!.toStringAsFixed(0)}%';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Home (E2E)',
          style: GoogleFonts.literata(fontWeight: FontWeight.w700),
        ),
      ),
      body: AppContentWidth(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            SoftCard(
              color: AppColors.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Live soil',
                    style: GoogleFonts.literata(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    key: const Key('e2e_soil_truth_kind'),
                    kind.name,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    key: const Key('e2e_moisture_value'),
                    'Moisture $moistureLabel',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (latest != null)
                    Text(
                      key: const Key('e2e_reading_id'),
                      'Reading ${latest.id}',
                    ),
                ],
              ),
            ),
            if (offline.isNotEmpty) ...[
              const SizedBox(height: 16),
              KeyedSubtree(
                key: const Key('e2e_device_offline_alert'),
                child: SoftCard(
                  color: const Color(0xFFFFDAD8),
                  child: Text(
                    offline.first.title,
                    style: const TextStyle(
                      color: Color(0xFF690005),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
