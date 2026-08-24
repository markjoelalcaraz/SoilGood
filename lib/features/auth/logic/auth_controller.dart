/// Logic/controller for login and signup forms (loading + visible error state).
///
/// Sits between the auth pages and AuthRepository. No layout code — pages listen
/// to this controller and render banners/buttons accordingly.
library;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/validation/app_validators.dart';
import '../data/auth_repository.dart';

/// Owns auth form state and exposes visible failures to the UI.
class AuthController extends ChangeNotifier {
  AuthController(this._repository);

  final AuthRepository _repository;

  bool isLoading = false;
  String? errorMessage;

  /// Signs in and returns true only after Supabase confirms success.
  Future<bool> signIn({required String email, required String password}) async {
    return _run(() => _repository.signIn(email: email, password: password));
  }

  /// Signs up and returns true only after Supabase confirms success.
  Future<bool> signUp({required String email, required String password}) async {
    final emailError = AppValidators.email(email);
    final passwordError = AppValidators.signupPassword(password);
    if (emailError != null || passwordError != null) {
      errorMessage = emailError ?? passwordError;
      notifyListeners();
      return false;
    }
    return _run(() => _repository.signUp(email: email, password: password));
  }

  /// Runs an auth request while keeping loading and error state consistent.
  Future<bool> _run(Future<AuthResponse> Function() operation) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final response = await operation();
      if (response.user == null) {
        throw const AuthException('Supabase did not return a user.');
      }
      return true;
    } on AuthException catch (error) {
      errorMessage = error.message;
      return false;
    } on Object catch (error) {
      errorMessage = 'Authentication failed: $error';
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
