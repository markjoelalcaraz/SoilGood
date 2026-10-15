/// Device-bound critical E2E entry (Android emulator / physical device).
///
/// Web is not supported by Flutter `integration_test`. This app also has no
/// Windows desktop target. For day-to-day CI on this machine use the harness
/// widget E2E instead:
///
/// `flutter test test/critical/e2e_critical_flows_test.dart`
///
/// When an Android device/emulator is connected:
/// `flutter test integration_test/critical_flows_e2e_test.dart -d <deviceId>`
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:integration_test/integration_test.dart';
import 'package:soil_sense/features/home/data/soil_reading.dart';
import 'package:soil_sense/testing/critical_e2e_host.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  final now = DateTime.utc(2026, 9, 17, 12, 0, 0);

  Future<void> pumpHost(WidgetTester tester, {Widget? host}) async {
    await tester.pumpWidget(host ?? CriticalE2eHost(now: now));
    await tester.pumpAndSettle();
  }

  Finder claimField() => find.descendant(
        of: find.byKey(const Key('e2e_claim_code_field')),
        matching: find.byType(TextFormField),
      );

  testWidgets('TC_DEVICE_001 valid claim → Home moisture (device E2E)', (
    tester,
  ) async {
    await pumpHost(tester);
    await tester.enterText(claimField(), kE2eValidClaimCode);
    await tester.tap(find.byKey(const Key('e2e_link_sensor_button')));
    await tester.pumpAndSettle();
    expect(find.text('Moisture 42%'), findsOneWidget);
  });

  testWidgets('TC_ALERT_001 stale reading shows offline on device', (tester) async {
    await pumpHost(
      tester,
      host: CriticalE2eHost(
        now: now,
        startOnHome: true,
        homeReadings: [
          SoilReading(
            id: 'stale',
            recordedAt: now.subtract(const Duration(hours: 5)),
            moisturePercent: 40,
          ),
        ],
      ),
    );
    expect(find.byKey(const Key('e2e_device_offline_alert')), findsOneWidget);
  });
}
