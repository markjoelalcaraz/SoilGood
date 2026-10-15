/// Account creation screen pushed from Login (outside the app shell).
///
/// Creates a Supabase Auth user; profile/farm/device are filled later in onboarding.
/// Uses the same visual language as the login page.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/validation/app_validators.dart';
import '../data/auth_repository.dart';
import '../logic/auth_controller.dart';
import 'widgets/auth_error_banner.dart';
import 'widgets/auth_primary_button.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/auth_text_field.dart';
import 'widgets/password_rules_checklist.dart';

/// Account creation page that reuses the login page's visual language.
class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  late final AuthController _authController;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _authController = AuthController(AuthRepository())..addListener(_refresh);
  }

  /// Rebuilds the form when loading or error state changes.
  void _refresh() {
    if (mounted) setState(() {});
  }

  /// Validates both passwords before creating the Supabase account.
  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final success = await _authController.signUp(
      email: _emailController.text,
      password: _passwordController.text,
    );
    if (success && mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _authController
      ..removeListener(_refresh)
      ..dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Create Account',
      subtitle: 'Start making informed decisions for your farm',
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
              hint: '8+ characters, letter, number, symbol',
              icon: Icons.lock_outline,
              obscureText: _obscurePassword,
              autofillHints: const [AutofillHints.newPassword],
              onChanged: (_) => setState(() {}),
              onToggleVisibility: () {
                setState(() => _obscurePassword = !_obscurePassword);
              },
              validator: AppValidators.signupPassword,
            ),
            const SizedBox(height: 10),
            PasswordRulesChecklist(password: _passwordController.text),
            const SizedBox(height: 14),
            AuthTextField(
              controller: _confirmController,
              label: 'Confirm Password',
              hint: 'Repeat your password',
              icon: Icons.lock_reset_outlined,
              obscureText: _obscureConfirm,
              autofillHints: const [AutofillHints.newPassword],
              onToggleVisibility: () {
                setState(() => _obscureConfirm = !_obscureConfirm);
              },
              validator: (value) => AppValidators.confirmPassword(
                value,
                _passwordController.text,
              ),
            ),
            const SizedBox(height: 20),
            AuthErrorBanner(message: _authController.errorMessage),
            if (_authController.errorMessage != null)
              const SizedBox(height: 16),
            AuthPrimaryButton(
              label: 'Create Account',
              isLoading: _authController.isLoading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
      footer: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.center,
        children: [
          const Text(
            'Already have an account?',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Sign In',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
