/// Screen shown after the farmer opens the password-reset link.
///
/// AuthGate routes here while a recovery session is active. Saving the new
/// password calls [onSaved] so the gate can enter the farm. Not a shell tab.
library;

import 'package:flutter/material.dart';

import '../data/auth_repository.dart';
import '../logic/auth_controller.dart';
import 'widgets/auth_error_banner.dart';
import 'widgets/auth_primary_button.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/auth_text_field.dart';
import 'widgets/password_rules_checklist.dart';

/// New-password form for a Supabase recovery session.
class SetNewPasswordPage extends StatefulWidget {
  const SetNewPasswordPage({required this.onSaved, super.key});

  final VoidCallback onSaved;

  @override
  State<SetNewPasswordPage> createState() => _SetNewPasswordPageState();
}

class _SetNewPasswordPageState extends State<SetNewPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  late final AuthController _authController;
  var _obscurePassword = true;
  var _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_refresh);
    _authController = AuthController(AuthRepository())..addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  /// Saves the new password, then lets AuthGate continue into the app.
  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final saved = await _authController.updatePassword(
      password: _passwordController.text,
      confirmPassword: _confirmController.text,
    );
    if (saved) widget.onSaved();
  }

  @override
  void dispose() {
    _authController
      ..removeListener(_refresh)
      ..dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'New password',
      subtitle: 'Choose a password you have not used here before',
      form: Form(
        key: _formKey,
        child: Column(
          children: [
            AuthTextField(
              controller: _passwordController,
              label: 'New password',
              hint: '••••••••',
              icon: Icons.lock_outline,
              obscureText: _obscurePassword,
              onToggleVisibility: () {
                setState(() => _obscurePassword = !_obscurePassword);
              },
            ),
            const SizedBox(height: 8),
            PasswordRulesChecklist(password: _passwordController.text),
            const SizedBox(height: 12),
            AuthTextField(
              controller: _confirmController,
              label: 'Confirm password',
              hint: '••••••••',
              icon: Icons.lock_outline,
              obscureText: _obscureConfirm,
              onToggleVisibility: () {
                setState(() => _obscureConfirm = !_obscureConfirm);
              },
            ),
            const SizedBox(height: 20),
            AuthErrorBanner(message: _authController.errorMessage),
            if (_authController.errorMessage != null)
              const SizedBox(height: 16),
            AuthPrimaryButton(
              whiteLabel: true,
              label: 'Save password',
              isLoading: _authController.isLoading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
      footer: const SizedBox.shrink(),
    );
  }
}
