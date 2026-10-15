/// Admin sign-in screen for the Lab Flasher Windows station.
///
/// Email/password against the same Supabase Auth as SoilGood. Shown before
/// the Provision & Flash UI when there is no admin session.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_colors.dart';

/// Simple email + password form for lab admins.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.bannerMessage});

  final String? bannerMessage;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Signs in; AuthGate re-checks admin role.
  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final banner = widget.bannerMessage;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Lab Flasher',
                    style: GoogleFonts.literata(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sign in with an admin SoilGood account.',
                    style: GoogleFonts.nunitoSans(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (banner != null && banner.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _ErrorBox(message: banner),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    _ErrorBox(message: _error!),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => _busy ? null : _submit(),
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: _busy ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                      child: _busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Sign in',
                              style: GoogleFonts.nunitoSans(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.errorSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        message,
        style: GoogleFonts.nunitoSans(
          color: AppColors.error,
          fontSize: 13,
        ),
      ),
    );
  }
}
