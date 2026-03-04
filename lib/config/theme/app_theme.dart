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
      tertiary: AppColors.accent,
      surface: AppColors.surfaceLight,
      error: AppColors.danger,
    ),
    dividerColor: AppColors.borderLight.withValues(alpha: 0.35),
    textTheme: AppTypography.light,
    extensions: <ThemeExtension<dynamic>>[
      AppThemeExtension(
        cardBackground: AppColors.surfaceLight,
        cardBorder: AppColors.borderLight,
        secondaryText: AppColors.textSecondaryLight,
        sidebarItemBackground: const Color(0xFFF1F5F9),
        subtleDivider: AppColors.textPrimaryLight.withValues(alpha: 0.1),
        selectedIndicator: AppColors.secondary,
        hoverOverlay: AppColors.secondary.withValues(alpha: 0.08),
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
      tertiary: AppColors.accent,
      surface: AppColors.surfaceDark,
      error: AppColors.danger,
    ),
    dividerColor: Colors.white.withValues(alpha: 0.08),
    textTheme: AppTypography.dark,
    extensions: <ThemeExtension<dynamic>>[
      AppThemeExtension(
        cardBackground: AppColors.surfaceDark,
        cardBorder: AppColors.borderDark,
        secondaryText: AppColors.textSecondaryDark,
        sidebarItemBackground: const Color(0xFF232323),
        subtleDivider: Colors.white.withValues(alpha: 0.1),
        selectedIndicator: AppColors.primary,
        hoverOverlay: AppColors.primary.withValues(alpha: 0.12),
      ),
    ],
  );
}
