/// Detects a Supabase password-recovery link and remembers it for this browser.
///
/// The email link opens SoilGood with `type=recovery`. AuthGate uses that to
/// show the new-password screen instead of the farm, until the farmer saves
/// a password or the recovery session is gone. Not a widget.
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_bootstrap.dart';
import 'auth_callback_stash_stub.dart'
    if (dart.library.html) 'auth_callback_stash_web.dart';

const _recoveryFlagKey = 'soilgood.password_recovery';

/// Set before the first frame when a reset link created a session, or when it failed.
abstract final class PasswordRecoveryLaunch {
  static var pending = false;
  static String? error;
}

/// True when [uri] is the link Supabase sends for a password reset.
bool uriRequestsPasswordRecovery(Uri uri) {
  return _params(uri)['type'] == 'recovery';
}

/// True when [uri] still carries a Supabase auth callback.
bool uriHasAuthCallback(Uri uri) {
  final params = _params(uri);
  return params['type'] == 'recovery' ||
      params.containsKey('code') ||
      params.containsKey('access_token') ||
      params.containsKey('token_hash') ||
      params.containsKey('error') ||
      params.containsKey('error_description');
}

/// Turns a saved reset link into a session. Call once after Supabase starts.
Future<void> recoverStashedAuthCallback() async {
  final raw = readStashedAuthCallback();
  if (raw == null || raw.isEmpty) return;
  final uri = Uri.tryParse(raw);
  if (uri == null || !uriHasAuthCallback(uri)) return;

  if (supabase.auth.currentSession != null) {
    await _markRecoveryPending();
    clearStashedAuthCallback();
    return;
  }

  try {
    final params = _params(uri);
    final tokenHash = params['token_hash'];
    if (params['type'] == 'recovery' &&
        tokenHash != null &&
        tokenHash.isNotEmpty) {
      await supabase.auth.verifyOTP(
        type: OtpType.recovery,
        tokenHash: tokenHash,
      );
    } else {
      await supabase.auth.getSessionFromUrl(uri);
    }
    if (supabase.auth.currentSession != null) {
      await _markRecoveryPending();
      clearStashedAuthCallback();
    }
  } on AuthException catch (error) {
    PasswordRecoveryLaunch.error = friendlyRecoveryError(error);
    clearStashedAuthCallback();
  } on Object catch (error) {
    PasswordRecoveryLaunch.error = friendlyRecoveryError(error);
    clearStashedAuthCallback();
  }
}

/// Farmer-facing text when the email link cannot start a reset session.
String friendlyRecoveryError(Object error) {
  final raw = error.toString();
  if (raw.contains('Code verifier could not be found')) {
    return 'Open the reset link in the same browser where you tapped '
        'Forgot password, while SoilGood is still open at that same address. '
        'If the address changed, request a new link.';
  }
  if (error is AuthException && error.message.trim().isNotEmpty) {
    return error.message;
  }
  return 'Could not open the reset link. Request a new one from Forgot password.';
}

Future<void> _markRecoveryPending() async {
  PasswordRecoveryLaunch.pending = true;
  PasswordRecoveryLaunch.error = null;
  await const PasswordRecoveryStore().write(true);
}

Map<String, String> _params(Uri uri) {
  return {...uri.queryParameters, ..._fragmentParams(uri)};
}

/// Where the reset email should send the farmer. Web uses this browser's origin.
String? passwordResetRedirect() {
  if (!kIsWeb) return null;
  return Uri.base.origin;
}

/// Remembers an unfinished reset so a refresh still asks for a new password.
class PasswordRecoveryStore {
  const PasswordRecoveryStore();

  Future<bool> read() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_recoveryFlagKey) ?? false;
  }

  Future<void> write(bool pending) async {
    final prefs = await SharedPreferences.getInstance();
    if (pending) {
      await prefs.setBool(_recoveryFlagKey, true);
    } else {
      await prefs.remove(_recoveryFlagKey);
    }
  }
}

Map<String, String> _fragmentParams(Uri uri) {
  var fragment = uri.fragment;
  if (fragment.startsWith('/')) fragment = fragment.substring(1);
  if (fragment.isEmpty || !fragment.contains('=')) return const {};
  try {
    return Uri.splitQueryString(fragment);
  } on FormatException {
    return const {};
  }
}
