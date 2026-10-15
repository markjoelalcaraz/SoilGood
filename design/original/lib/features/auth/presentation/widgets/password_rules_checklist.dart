/// Live signup password checklist — which strength rules are still unmet.
///
/// Shown under the signup password field so farmers see missing letter / number
/// / symbol before they tap Create Account. Presentation only.
library;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/validation/app_validators.dart';

/// Compact rule list that updates as the farmer types a new password.
class PasswordRulesChecklist extends StatelessWidget {
  const PasswordRulesChecklist({required this.password, super.key});

  final String password;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final rule in AppValidators.signupPasswordRules)
          _RuleRow(label: rule.label, met: rule.isSatisfied(password)),
      ],
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.label, required this.met});

  final String label;
  final bool met;

  @override
  Widget build(BuildContext context) {
    final color = met ? AppColors.primary : AppColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: met ? FontWeight.w700 : FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
