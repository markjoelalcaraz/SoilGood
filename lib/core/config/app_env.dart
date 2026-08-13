/// Core config helper that loads secrets from the .env file.
///
/// Not a screen. Used at startup for Supabase. Groq lives in Edge Function
/// secrets — never in this client `.env`.
library;

import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Loads and validates Supabase credentials from `.env`.
/// Fails visibly if keys are missing — no silent defaults during development.
class AppEnv {
  AppEnv._();

  static const String _urlKey = 'SUPABASE_URL';
  static const String _anonKey = 'SUPABASE_ANON_KEY';

  /// Load `.env` from assets. Call once before [Supabase.initialize].
  static Future<void> load() async {
    await dotenv.load(fileName: '.env');
    _require(_urlKey);
    _require(_anonKey);
  }

  static String get supabaseUrl => _require(_urlKey);

  static String get supabaseAnonKey => _require(_anonKey);

  static String _require(String key) {
    final value = dotenv.env[key]?.trim() ?? '';
    if (value.isEmpty) {
      throw StateError(
        'Missing $key in .env. Copy .env.example to .env and fill Supabase values.',
      );
    }
    return value;
  }
}
