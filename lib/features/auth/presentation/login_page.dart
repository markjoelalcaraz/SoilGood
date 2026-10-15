/// Login screen shown before the farmer enters the app shell.
///
/// Full-bleed farm picture with the welcome sheet over it, matching the
/// reinvent mock. On success, AuthGate continues to onboarding or the shell.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/validation/app_validators.dart';
import '../../../shared/widgets/app_content_width.dart';
import '../data/auth_repository.dart';
import '../logic/auth_controller.dart';
import '../../../shared/navigation/app_page_routes.dart';
import 'forgot_password_page.dart';
import 'signup_page.dart';
import 'splash_page.dart';
import 'widgets/auth_error_banner.dart';
import 'widgets/auth_primary_button.dart';
import 'widgets/auth_text_field.dart';

/// Email/password login: farm illustration, then the welcome sheet.
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

  /// Opens the reset-email page with the email already typed, if any.
  void _openForgotPassword() {
    Navigator.of(context).push(
      AppPageRoutes.slideFromRight(
        ForgotPasswordPage(initialEmail: _emailController.text),
      ),
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
    final screenH = MediaQuery.sizeOf(context).height;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final heroH = keyboard > 0 ? 110.0 : (screenH * 0.34).clamp(180.0, 300.0);

    return Scaffold(
      backgroundColor: const Color(0xFFFBFAF7),
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: heroH,
            child: const _LoginFarmPhoto(),
          ),
          Positioned(
            top: heroH - 22,
            left: 0,
            right: 0,
            bottom: 0,
            child: ColoredBox(
              color: const Color(0xFFFBFAF7),
              child: AppContentWidth(
                maxWidth: kAuthContentMaxWidth,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: Color(0xFFFBFAF7),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 26, 20, 24),
                children: [
                  Text(
                    'Welcome back',
                    style: GoogleFonts.literata(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Sign in to access your farm dashboard',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        AuthTextField(
                          controller: _emailController,
                          label: 'Email',
                          hint: 'juan@farm.ph',
                          icon: Icons.mail_outline,
                          showLabel: false,
                          fillColor: Colors.white,
                          keyboardType: TextInputType.emailAddress,
                          validator: AppValidators.email,
                        ),
                        const SizedBox(height: 14),
                        AuthTextField(
                          controller: _passwordController,
                          label: 'Password',
                          hint: 'Password',
                          icon: Icons.lock_outline,
                          showLabel: false,
                          fillColor: const Color(0xFFF3F1EC),
                          obscureText: _obscurePassword,
                          onToggleVisibility: () {
                            setState(
                              () => _obscurePassword = !_obscurePassword,
                            );
                          },
                          validator: AppValidators.loginPassword,
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              minimumSize: const Size(48, 40),
                              foregroundColor: AppColors.navIcon,
                            ),
                            onPressed: _authController.isLoading
                                ? null
                                : _openForgotPassword,
                            child: const Text(
                              'Forgot password?',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                        AuthErrorBanner(message: _authController.errorMessage),
                        if (_authController.errorMessage != null)
                          const SizedBox(height: 12),
                        AuthPrimaryButton(
                          whiteLabel: true,
                          label: 'Sign In',
                          isLoading: _authController.isLoading,
                          onPressed: _submit,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 17,
                        color: AppColors.textSecondary,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Secure Login',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: WrapAlignment.center,
                    children: [
                      const Text(
                        'Don’t have an account?',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      TextButton(
                        onPressed: _openSignup,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.navIcon,
                        ),
                        child: const Text(
                          'Create Account',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Farm picture on login. Starts close, then settles once the splash has cleared.
class _LoginFarmPhoto extends StatefulWidget {
  const _LoginFarmPhoto();

  @override
  State<_LoginFarmPhoto> createState() => _LoginFarmPhotoState();
}

class _LoginFarmPhotoState extends State<_LoginFarmPhoto>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  var _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1150),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started || !AppReveal.readyOf(context)) return;
    _started = true;
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motion = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRect(
          child: AnimatedBuilder(
            animation: motion,
            builder: (context, child) {
              final t = motion.value;
              return Transform.translate(
                offset: Offset(0, 16 * (1 - t)),
                child: Transform.scale(
                  scale: 1.22 - (0.22 * t),
                  child: child,
                ),
              );
            },
            child: Image.asset(
              'assets/farm/farm-banner.jpg',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
        ),
        Positioned(
          top: MediaQuery.paddingOf(context).top + 8,
          left: 16,
          child: Text(
            'SoilGood',
            style: GoogleFonts.literata(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              shadows: const [
                Shadow(color: Color(0x66000000), blurRadius: 8),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
