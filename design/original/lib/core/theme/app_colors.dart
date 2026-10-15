/// Core design tokens — every SoilGood color lives here (primary green, cream, text, error).
///
/// Not a screen. Feature pages and shared widgets import these constants so the
/// UI stays consistent with docs/context/UI_THEME.md.
library;

import 'package:flutter/material.dart';

/// Central SoilGood color tokens used by every feature.
abstract final class AppColors {
  static const primary = Color(0xFF4A7C59);
  static const primaryContainer = Color(0xFF78A886);
  static const primarySoft = Color(0xFFC8E8D0);
  static const tertiary = Color(0xFF705C30);
  static const tertiarySoft = Color(0xFFF8E0A8);
  static const secondary = Color(0xFF6B6358);
  static const secondaryContainer = Color(0xFFF0E8DB);
  static const background = Color(0xFFFAF6F0);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF0ECE4);
  static const surfaceLow = Color(0xFFF5F1EA);
  static const surfaceHigh = Color(0xFFE4E0D8);
  static const textPrimary = Color(0xFF2E3230);
  static const textSecondary = Color(0xFF4A4E4A);
  static const outline = Color(0xFFC4C8BC);
  static const error = Color(0xFFB83230);
  static const errorContainer = Color(0xFFFFDAD8);
}
