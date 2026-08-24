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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
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
