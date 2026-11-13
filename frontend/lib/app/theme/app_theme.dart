import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static const String fontFamily = 'Manrope';

  static TextTheme get _textTheme {
    const base = TextStyle(
      fontFamily: fontFamily,
      color: AppColors.text,
      height: 1.35,
      letterSpacing: -0.15,
    );
    return TextTheme(
      displayLarge: base.copyWith(
        fontSize: 40,
        fontWeight: FontWeight.w800,
        height: 1.15,
        letterSpacing: -0.8,
      ),
      displayMedium: base.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        height: 1.18,
        letterSpacing: -0.6,
      ),
      headlineLarge: base.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        height: 1.2,
        letterSpacing: -0.5,
      ),
      headlineMedium: base.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.25,
        letterSpacing: -0.4,
      ),
      headlineSmall: base.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.25,
        letterSpacing: -0.3,
      ),
      titleLarge: base.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        height: 1.3,
        letterSpacing: -0.25,
      ),
      titleMedium: base.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.3,
        letterSpacing: -0.2,
      ),
      titleSmall: base.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.3,
        letterSpacing: -0.1,
      ),
      bodyLarge: base.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      bodyMedium: base.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      bodySmall: base.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.secondaryText,
      ),
      labelLarge: base.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.1,
      ),
      labelMedium: base.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      labelSmall: base.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
    );
  }

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.lightBlue,
          surface: AppColors.white,
        ),
        scaffoldBackgroundColor: AppColors.background,
        fontFamily: fontFamily,
        textTheme: _textTheme,
        primaryTextTheme: _textTheme,
      );
}
