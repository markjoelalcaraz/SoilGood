/// Shared primary action button for auth and onboarding forms (with loading state).
///
/// Keeps Login/Signup/Onboarding CTAs looking consistent. Widget only — no
/// business logic beyond disabling while a request runs.
library;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Shared primary auth action with a built-in loading state.
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
    this.whiteLabel = false,
    super.key,
  });

  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  /// Splash and login use white words on the green button. Other screens keep dark text.
  final bool whiteLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.buttonGreen,
          foregroundColor: whiteLabel ? Colors.white : AppColors.textPrimary,
          disabledBackgroundColor: AppColors.buttonGreen.withValues(
            alpha: 0.65,
          ),
          shape: const StadiumBorder(),
        ),
        child: isLoading
            ? SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(
                  color: whiteLabel ? Colors.white : AppColors.textPrimary,
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
      ),
    );
  }
}
