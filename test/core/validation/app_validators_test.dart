import 'package:flutter_test/flutter_test.dart';
import 'package:soil_sense/core/validation/app_validators.dart';

void main() {
  group('AppValidators.email', () {
    test('rejects empty and implausible addresses', () {
      expect(AppValidators.email(''), isNotNull);
      expect(AppValidators.email('a@b.'), isNotNull);
      expect(AppValidators.email('hi@x'), isNotNull);
      expect(AppValidators.email('not-an-email'), isNotNull);
    });

    test('accepts a normal farm email', () {
      expect(AppValidators.email('farmer@example.com'), isNull);
      expect(AppValidators.email('  farmer@example.com  '), isNull);
    });
  });

  group('AppValidators.signupPassword', () {
    test('requires 8+ characters, a letter, a number, and a symbol', () {
      expect(AppValidators.signupPassword('password'), isNotNull);
      expect(AppValidators.signupPassword('Password1'), isNotNull);
      expect(AppValidators.signupPassword('Pass1!'), isNotNull);
      expect(AppValidators.signupPassword('Farmpass1!'), isNull);
    });

    test('login does not enforce strength', () {
      expect(AppValidators.loginPassword('short'), isNull);
      expect(AppValidators.loginPassword(''), isNotNull);
    });
  });

  group('AppValidators.confirmPassword', () {
    test('must match exactly', () {
      expect(AppValidators.confirmPassword('Farmpass1!', 'Farmpass1!'), isNull);
      expect(AppValidators.confirmPassword('other', 'Farmpass1!'), isNotNull);
    });
  });
}
