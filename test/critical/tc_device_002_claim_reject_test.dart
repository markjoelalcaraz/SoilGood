/// TC_DEVICE_002 — Reject empty / unknown / used claim codes (unit).
///
/// Related: TS-01 Device claim. Docs: docs/testing/CRITICAL_TEST_CASES.md
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:soil_sense/features/onboarding/logic/device_claim_rules.dart';

void main() {
  group('TC_DEVICE_002 reject bad claim codes', () {
    test('empty or whitespace claim code is rejected before RPC', () {
      expect(normalizeClaimCode(''), isNull);
      expect(normalizeClaimCode('   '), isNull);
      expect(kEmptyClaimCodeMessage, contains('claim code'));
    });

    test('unknown claim code maps to farmer-facing not-found message', () {
      final err = Exception(
        'PostgrestException(message: Claim code not found. Check the code on your box, code: P0001)',
      );
      expect(
        friendlyClaimError(err),
        'Claim code not found. Check the code on your box',
      );
    });

    test('already-used claim code maps to used message', () {
      final err = Exception('This claim code was already used');
      expect(friendlyClaimError(err), 'This claim code was already used');
    });

    test('farm already has a sensor maps to linked message', () {
      final err = Exception('This farm already has a sensor linked');
      expect(
        friendlyClaimError(err),
        'This farm already has a sensor linked',
      );
    });

    test('generic claim_device / PGRST failure stays farmer-safe', () {
      expect(
        friendlyClaimError(Exception('rpc claim_device failed PGRST116')),
        'Could not link sensor. Ask your installer to run device claim SQL, then try again.',
      );
    });
  });

  group('TC_DEVICE_001 normalize happy path (unit slice)', () {
    test('trims and uppercases sticker code', () {
      expect(normalizeClaimCode('  sg-7k2m  '), 'SG-7K2M');
    });
  });
}
