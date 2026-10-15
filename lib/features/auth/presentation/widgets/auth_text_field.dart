/// Themed text field widget reused by login, signup, and onboarding forms.
///
/// Presentation helper only — labels, obscure toggle, and SoilGood styling.
library;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Reusable labeled field used by all SoilGood auth forms.
class AuthTextField extends StatelessWidget {
  const AuthTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.onToggleVisibility,
    this.validator,
    this.onChanged,
    this.autofillHints,
    this.showLabel = true,
    this.fillColor,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final VoidCallback? onToggleVisibility;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final Iterable<String>? autofillHints;

  /// Login hides the label so the field matches the mock’s icon row.
  final bool showLabel;

  /// When set, the field uses this fill (login email is white, password is warm).
  final Color? fillColor;

  /// Login corners stay a short rounded rect. A large radius turns the field into a long pill.
  InputBorder? _loginBorder(Color color, {double width = 1}) {
    if (fillColor == null) return null;
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel) ...[
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          validator: validator,
          onChanged: onChanged,
          autofillHints:
              autofillHints ??
              (keyboardType == TextInputType.emailAddress
                  ? const [AutofillHints.email]
                  : (obscureText ? const [AutofillHints.password] : null)),
          decoration: InputDecoration(
            hintText: hint,
            isDense: fillColor != null,
            contentPadding: fillColor == null
                ? null
                : const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
            filled: fillColor != null ? true : null,
            fillColor: fillColor,
            border: _loginBorder(const Color(0xFFD7E0D8)),
            enabledBorder: _loginBorder(const Color(0xFFD7E0D8)),
            focusedBorder: _loginBorder(AppColors.buttonGreen, width: 1.5),
            errorBorder: _loginBorder(AppColors.error),
            focusedErrorBorder: _loginBorder(AppColors.error, width: 1.5),
            prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 21),
            suffixIcon: onToggleVisibility == null
                ? null
                : IconButton(
                    tooltip: obscureText ? 'Show password' : 'Hide password',
                    onPressed: onToggleVisibility,
                    icon: Icon(
                      obscureText
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AppColors.textSecondary,
                      size: 21,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
