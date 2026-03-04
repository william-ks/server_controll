import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_theme_extension.dart';
import 'app_typography.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.scaffoldLight,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.surfaceLight,
      error: AppColors.danger,
    ),
    textTheme: AppTypography.light,
    extensions: const <ThemeExtension<dynamic>>[
      AppThemeExtension(
        cardBackground: AppColors.surfaceLight,
        cardBorder: AppColors.borderLight,
        secondaryText: AppColors.textSecondaryLight,
        sidebarItemBackground: Color(0xFFF1F5F9),
      ),
    ],
  );

  static ThemeData dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.scaffoldDark,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.surfaceDark,
      error: AppColors.danger,
    ),
    textTheme: AppTypography.dark,
    extensions: const <ThemeExtension<dynamic>>[
      AppThemeExtension(
        cardBackground: AppColors.surfaceDark,
        cardBorder: AppColors.borderDark,
        secondaryText: AppColors.textSecondaryDark,
        sidebarItemBackground: Color(0xFF1E2533),
      ),
    ],
  );
}

