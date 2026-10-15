/// Critical UI E2E flows — claim → Home truth → offline alert (harness, no Supabase).
///
/// Same Template A/B coverage as device/home/alert critical cases, but drives
/// real widgets with taps and typed input. Run:
/// `flutter test test/critical/e2e_critical_flows_test.dart`
///
/// Device-bound `integration_test/` needs an Android emulator (web is unsupported;
/// this app has no Windows desktop target). Docs: docs/testing/CRITICAL_TEST_CASES.md
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:soil_sense/features/home/data/soil_reading.dart';
import 'package:soil_sense/testing/critical_e2e_host.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  final now = DateTime.utc(2026, 9, 17, 12, 0, 0);

  Future<void> pumpHost(WidgetTester tester, {Widget? host}) async {
    await tester.pumpWidget(host ?? CriticalE2eHost(now: now));
    await tester.pumpAndSettle();
  }

  Finder claimField() => find.descendant(
        of: find.byKey(const Key('e2e_claim_code_field')),
        matching: find.byType(TextFormField),
      );

  group('E2E TC_DEVICE claim', () {
    testWidgets('TC_DEVICE_002 empty code shows Required', (tester) async {
      await pumpHost(tester);
      await tester.tap(find.byKey(const Key('e2e_link_sensor_button')));
      await tester.pumpAndSettle();
      expect(find.text('Required'), findsOneWidget);
    });

    testWidgets('TC_DEVICE_002 used code shows farmer error', (tester) async {
      await pumpHost(tester);
      await tester.enterText(claimField(), kE2eUsedClaimCode);
      await tester.tap(find.byKey(const Key('e2e_link_sensor_button')));
      await tester.pumpAndSettle();
      expect(find.text('This claim code was already used'), findsOneWidget);
      expect(find.text('Home (E2E)'), findsNothing);
    });

    testWidgets('TC_DEVICE_001 valid code opens Home soil panel', (tester) async {
      await pumpHost(tester);
      await tester.enterText(claimField(), '  sg-7k2m  ');
      await tester.tap(find.byKey(const Key('e2e_link_sensor_button')));
      await tester.pumpAndSettle();
      expect(find.text('Home (E2E)'), findsOneWidget);
      expect(find.byKey(const Key('e2e_moisture_value')), findsOneWidget);
      expect(find.text('Moisture 42%'), findsOneWidget);
      expect(find.text('Reading new'), findsOneWidget);
    });
  });

  group('E2E TC_HOME live soil truth', () {
    testWidgets('TC_HOME_001 shows newest reading', (tester) async {
      await pumpHost(
        tester,
        host: CriticalE2eHost(
          now: now,
          startOnHome: true,
          homeReadings: [
            SoilReading(
              id: 'a',
              recordedAt: now.subtract(const Duration(hours: 3)),
              moisturePercent: 20,
            ),
            SoilReading(
              id: 'b',
              recordedAt: now.subtract(const Duration(minutes: 5)),
              moisturePercent: 42,
              ph: 6.4,
            ),
          ],
        ),
      );
      expect(find.text('live'), findsOneWidget);
      expect(find.text('Moisture 42%'), findsOneWidget);
      expect(find.text('Reading b'), findsOneWidget);
    });

    testWidgets('TC_HOME_002 empty stays empty not fake live', (tester) async {
      await pumpHost(
        tester,
        host: CriticalE2eHost(
          now: now,
          startOnHome: true,
          homeReadings: const [],
        ),
      );
      expect(find.text('empty'), findsOneWidget);
      expect(find.text('Moisture —'), findsOneWidget);
      expect(find.byKey(const Key('e2e_device_offline_alert')), findsNothing);
    });

    testWidgets('TC_HOME_002 / TC_ALERT_001 stale shows offline alert', (
      tester,
    ) async {
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
      expect(find.text('stale'), findsOneWidget);
      expect(find.byKey(const Key('e2e_device_offline_alert')), findsOneWidget);
      expect(find.textContaining('Sensor has not reported'), findsOneWidget);
    });
  });
}
