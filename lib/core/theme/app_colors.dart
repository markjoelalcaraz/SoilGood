/// Core design tokens — every SoilGood color lives here (primary green, cream, text, error).
///
/// Not a screen. Feature pages and shared widgets import these constants so the
/// UI stays consistent with docs/context/UI_THEME.md.
library;

import 'package:flutter/material.dart';

/// Central SoilGood color tokens used by every feature.
abstract final class AppColors {
  static const primary = Color(0xFF62A844);
  static const primaryContainer = Color(0xFF6AAF45);
  static const primarySoft = Color(0xFFC8EEB0);
  static const buttonGreen = Color(0xFF6AAF45);
  static const navIcon = Color(0xFF4E9434);
  static const tertiary = Color(0xFF705C30);
  static const tertiarySoft = Color(0xFFF8E0A8);
  static const secondary = Color(0xFF6B6358);
  static const secondaryContainer = Color(0xFFF0E8DB);
  static const background = Color(0xFFF6F8F3);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF3F7F1);
  static const surfaceLow = Color(0xFFF3F7F1);
  static const surfaceHigh = Color(0xFFE7F0E4);
  static const textPrimary = Color(0xFF243028);
  static const textSecondary = Color(0xFF5C6760);
  static const outline = Color(0xFFC4C8BC);
  static const error = Color(0xFFB83230);
  static const errorContainer = Color(0xFFFFDAD8);
}
