/// Core theme builder that turns SoilGood colors + Literata/Nunito into Material 3 ThemeData.
///
/// Applied once on the root MaterialApp so every screen inherits the same look
/// without each page inventing its own styling.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Builds the shared SoilGood Material theme.
abstract final class AppTheme {
  static ThemeData get light {
    final bodyTheme = GoogleFonts.nunitoSansTextTheme();
    final headlineTheme = GoogleFonts.literataTextTheme();

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        surface: AppColors.surface,
        error: AppColors.error,
      ),
      textTheme: bodyTheme
          .copyWith(
            displayLarge: headlineTheme.displayLarge,
            displayMedium: headlineTheme.displayMedium,
            displaySmall: headlineTheme.displaySmall,
            headlineLarge: headlineTheme.headlineLarge,
            headlineMedium: headlineTheme.headlineMedium,
            headlineSmall: headlineTheme.headlineSmall,
            titleLarge: headlineTheme.titleLarge,
          )
          .apply(
            bodyColor: AppColors.textPrimary,
            displayColor: AppColors.textPrimary,
          ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: _border(AppColors.outline),
        enabledBorder: _border(AppColors.outline),
        focusedBorder: _border(AppColors.primary, width: 1.5),
        errorBorder: _border(AppColors.error),
        focusedErrorBorder: _border(AppColors.error, width: 1.5),
      ),
    );
  }

  /// Creates consistent rounded borders for all form fields.
  static OutlineInputBorder _border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
