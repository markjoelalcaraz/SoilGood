/// Password-reset links are recognized by the `type=recovery` query Supabase adds.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:soil_sense/features/auth/logic/password_recovery.dart';

void main() {
  test('recovery email link is detected from the query', () {
    final uri = Uri.parse('http://localhost:5000/?type=recovery&code=abc');
    expect(uriRequestsPasswordRecovery(uri), isTrue);
  });

  test('recovery email link is detected from the hash', () {
    final uri = Uri.parse(
      'http://localhost:5000/#access_token=token&type=recovery',
    );
    expect(uriRequestsPasswordRecovery(uri), isTrue);
  });

  test('a code callback is an auth link even without type=recovery', () {
    final uri = Uri.parse('http://localhost:5000/?code=abc');
    expect(uriHasAuthCallback(uri), isTrue);
    expect(uriRequestsPasswordRecovery(uri), isFalse);
  });

  test('a normal app open is not a password reset', () {
    expect(
      uriRequestsPasswordRecovery(Uri.parse('http://localhost:5000/')),
      isFalse,
    );
  });
}
