/// Loads Lab Flasher secrets from `.env` (filesystem first, then assets).
///
/// Desktop tooling prefers a file in the working directory or the repo root
/// so ops can share SoilGood Supabase keys plus lab WiFi. Fails visibly if
/// required keys are missing — no silent defaults.
library;

import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Lab Flasher env: Supabase anon + lab WiFi for SGCFG inject.
class LabEnv {
  LabEnv._();

  static const _urlKey = 'SUPABASE_URL';
  static const _anonKey = 'SUPABASE_ANON_KEY';
  static const _ssidKey = 'WIFI_SSID';
  static const _passKey = 'WIFI_PASSWORD';

  /// Call once from [main] before Supabase init.
  static Future<void> load() async {
    final fromDisk = await _tryLoadFromDisk();
    if (!fromDisk) {
      throw StateError(
        'No .env found. Copy tooling/lab_flasher/.env.example to '
        'tooling/lab_flasher/.env (or add keys to the repo-root .env).',
      );
    }
    _require(_urlKey);
    _require(_anonKey);
    _require(_ssidKey);
    _require(_passKey);
  }

  static String get supabaseUrl => _require(_urlKey);
  static String get supabaseAnonKey => _require(_anonKey);
  static String get wifiSsid => _require(_ssidKey);
  static String get wifiPassword => _require(_passKey);

  static Future<bool> _tryLoadFromDisk() async {
    final sep = Platform.pathSeparator;
    final cwd = Directory.current.path;
    final candidates = <File>[
      File('.env'),
      File('$cwd$sep.env'),
      File('$cwd$sep..$sep..$sep.env'),
    ];
    for (final file in candidates) {
      if (!await file.exists()) continue;
      final content = await file.readAsString();
      if (content.trim().isEmpty) continue;
      dotenv.loadFromString(envString: content);
      return true;
    }
    return false;
  }

  static String _require(String key) {
    final value = dotenv.env[key]?.trim() ?? '';
    if (value.isEmpty) {
      throw StateError(
        'Missing $key. Copy tooling/lab_flasher/.env.example to .env '
        '(or add WIFI_SSID / WIFI_PASSWORD to the repo-root .env).',
      );
    }
    return value;
  }
}
