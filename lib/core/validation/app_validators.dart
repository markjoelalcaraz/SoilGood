/// Shared input validators used by login, signup, and later onboarding forms.
///
/// Pure functions — no widgets. Pages call these from `TextFormField.validator`
/// so rules live in one place instead of being copied per screen.
library;

/// One signup password rule shown in the live checklist.
class PasswordRule {
  const PasswordRule({
    required this.id,
    required this.label,
    required this.isSatisfied,
  });

  final String id;
  final String label;
  final bool Function(String password) isSatisfied;
}

/// Central validators for SoilGood auth (and later profile) fields.
abstract final class AppValidators {
  static final RegExp _emailPattern = RegExp(
    r'^[^@\s]+@[^@\s]+\.[A-Za-z]{2,}$',
  );
  static final RegExp _letter = RegExp(r'\p{L}', unicode: true);
  static final RegExp _digit = RegExp(r'\p{N}', unicode: true);

  /// bcrypt (used by Supabase Auth) ignores characters after this.
  static const int maxPasswordLength = 72;
  static const int minPasswordLength = 8;
  static const int maxEmailLength = 254;

  /// Live checklist rows for the signup password field.
  static const List<PasswordRule> signupPasswordRules = [
    PasswordRule(
      id: 'length',
      label: 'At least 8 characters',
      isSatisfied: _hasMinLength,
    ),
    PasswordRule(
      id: 'letter',
      label: 'A letter',
      isSatisfied: _hasLetter,
    ),
    PasswordRule(
      id: 'number',
      label: 'A number',
      isSatisfied: _hasDigit,
    ),
    PasswordRule(
      id: 'symbol',
      label: 'A symbol (! @ # % …)',
      isSatisfied: _hasSymbol,
    ),
  ];

  static bool _hasMinLength(String password) =>
      password.length >= minPasswordLength;

  static bool _hasLetter(String password) => _letter.hasMatch(password);

  static bool _hasDigit(String password) => _digit.hasMatch(password);

  /// Any non-letter, non-digit, non-whitespace character counts as a symbol.
  static bool _hasSymbol(String password) {
    for (final rune in password.runes) {
      final ch = String.fromCharCode(rune);
      if (ch.trim().isEmpty) continue;
      if (!_letter.hasMatch(ch) && !_digit.hasMatch(ch)) return true;
    }
    return false;
  }

  /// Login and signup email — requires a domain with a real TLD (not `a@b.`).
  static String? email(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Email is required.';
    if (email.length > maxEmailLength) {
      return 'Email is too long.';
    }
    if (!_emailPattern.hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  /// Login only — do not enforce strength here (existing accounts may be older).
  static String? loginPassword(String? value) {
    if ((value ?? '').isEmpty) return 'Password is required.';
    return null;
  }

  /// Signup password: length + letter + number + symbol.
  static String? signupPassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Password is required.';
    if (password.length > maxPasswordLength) {
      return 'Use $maxPasswordLength characters or fewer.';
    }
    final unmet = signupPasswordRules
        .where((rule) => !rule.isSatisfied(password))
        .toList();
    if (unmet.isEmpty) return null;
    if (unmet.length == 1) return 'Add ${unmet.single.label.toLowerCase()}.';
    return 'Use 8+ characters with a letter, a number, and a symbol.';
  }

  /// Confirm-password field must match the first password exactly.
  static String? confirmPassword(String? value, String password) {
    if ((value ?? '').isEmpty) return 'Confirm your password.';
    if (value != password) return 'Passwords do not match.';
    return null;
  }
}
