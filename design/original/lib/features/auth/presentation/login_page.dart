/// Login screen shown before the farmer enters the app shell.
///
/// Email/password sign-in UI matching the editorial mockup. On success, AuthGate
/// continues to onboarding or the shell depending on saved progress.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/validation/app_validators.dart';
import '../data/auth_repository.dart';
import '../logic/auth_controller.dart';
import '../../../shared/navigation/app_page_routes.dart';
import 'signup_page.dart';
import 'widgets/auth_error_banner.dart';
import 'widgets/auth_primary_button.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/auth_text_field.dart';

/// Email/password login page matching the approved editorial mockup.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late final AuthController _authController;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _authController = AuthController(AuthRepository())..addListener(_refresh);
  }

  /// Rebuilds the form when loading or error state changes.
  void _refresh() {
    if (mounted) setState(() {});
  }

  /// Validates fields before asking Supabase to authenticate.
  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    await _authController.signIn(
      email: _emailController.text,
      password: _passwordController.text,
    );
  }

  /// Opens the matching account creation page.
  void _openSignup() {
    Navigator.of(
      context,
    ).push(AppPageRoutes.slideFromRight(const SignupPage()));
  }

  @override
  void dispose() {
    _authController
      ..removeListener(_refresh)
      ..dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Welcome Back',
      subtitle: 'Sign in to access your farm dashboard',
      form: Form(
        key: _formKey,
        child: Column(
          children: [
            AuthTextField(
              controller: _emailController,
              label: 'Email Address',
              hint: 'farmer@example.com',
              icon: Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
              validator: AppValidators.email,
            ),
            const SizedBox(height: 20),
            AuthTextField(
              controller: _passwordController,
              label: 'Password',
              hint: '••••••••',
              icon: Icons.lock_outline,
              obscureText: _obscurePassword,
              onToggleVisibility: () {
                setState(() => _obscurePassword = !_obscurePassword);
              },
              validator: AppValidators.loginPassword,
            ),
            const SizedBox(height: 20),
            AuthErrorBanner(message: _authController.errorMessage),
            if (_authController.errorMessage != null)
              const SizedBox(height: 16),
            AuthPrimaryButton(
              label: 'Sign In',
              isLoading: _authController.isLoading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
      footer: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.shield_outlined,
                size: 17,
                color: AppColors.textSecondary,
              ),
              SizedBox(width: 5),
              Text(
                'Secure Login',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.center,
            children: [
              const Text(
                'Don’t have an account?',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              TextButton(
                onPressed: _openSignup,
                child: const Text(
                  'Create Account',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
