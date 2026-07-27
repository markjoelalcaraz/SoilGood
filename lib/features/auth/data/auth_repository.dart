/// Data-layer auth helpers — talks to Supabase Auth only (no widgets).
///
/// Sign-in, sign-up, and sign-out live here so presentation pages stay thin.
/// AuthController and Profile (sign out) call into this repository.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_bootstrap.dart';

/// Keeps Supabase authentication calls outside presentation widgets.
class AuthRepository {
  /// Signs an existing farmer into SoilGood.
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return supabase.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Creates a farmer account; the database trigger creates its profile row.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) {
    return supabase.auth.signUp(email: email.trim(), password: password);
  }

  /// Ends the current Supabase session.
  Future<void> signOut() => supabase.auth.signOut();
}
