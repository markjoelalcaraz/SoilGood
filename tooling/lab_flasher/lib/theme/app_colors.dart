/// SoilGood color tokens for the Lab Flasher desktop window.
///
/// Mirrors the main app primary green / matte surfaces so the flasher feels
/// like part of SoilGood, not a separate product skin.
library;

import 'package:flutter/material.dart';

/// Lab Flasher color tokens (aligned with docs/context/UI_THEME.md).
abstract final class AppColors {
  static const primary = Color(0xFF4A7C59);
  static const primarySoft = Color(0xFFE4EFE8);
  static const background = Color(0xFFF4F6F4);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF2C2C2C);
  static const textSecondary = Color(0xFF5C645E);
  static const outline = Color(0xFFC5CEC7);
  static const error = Color(0xFFA33B3B);
  static const errorSoft = Color(0xFFF6EAEA);
}
