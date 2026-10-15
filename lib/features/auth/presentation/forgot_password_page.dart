/// Pushed page from Login where the farmer asks for a password reset email.
///
/// Outside the app shell. Supabase sends the link; this page does not change
/// the password itself. The farmer opens the link in this same browser.
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

/// Email form that requests a Supabase password-reset message.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({this.initialEmail = '', super.key});

  final String initialEmail;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  late final AuthController _authController;
  var _sent = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail.trim());
    _authController = AuthController(AuthRepository())..addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  /// Sends the reset email and stays on this page so the farmer can read it.
  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final sent = await _authController.sendPasswordReset(
      email: _emailController.text,
    );
    if (sent && mounted) setState(() => _sent = true);
  }

  @override
  void dispose() {
    _authController
      ..removeListener(_refresh)
      ..dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Forgot password',
      subtitle: 'We will email you a link to choose a new one',
      form: _sent ? _sentCard() : _form(),
      footer: TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Back to sign in'),
      ),
    );
  }

  Widget _form() {
    return Form(
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
          AuthErrorBanner(message: _authController.errorMessage),
          if (_authController.errorMessage != null) const SizedBox(height: 16),
          AuthPrimaryButton(
            whiteLabel: true,
            label: 'Send reset link',
            isLoading: _authController.isLoading,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }

  Widget _sentCard() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Check that email',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        SizedBox(height: 8),
        Text(
          'If it has a SoilGood account, a reset link is on the way. '
          'Open the link in this same browser, then choose a new password.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.45),
        ),
      ],
    );
  }
}
