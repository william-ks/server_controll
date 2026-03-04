import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_styles.dart';
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
    cardTheme: CardThemeData(
      color: AppColors.surfaceLight,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: AppStyles.radiusMd),
      shadowColor: Colors.black.withValues(alpha: 0.08),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surfaceLight,
      shape: RoundedRectangleBorder(borderRadius: AppStyles.radiusLg),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: AppStyles.radiusSm,
        borderSide: BorderSide(color: AppColors.borderLight.withValues(alpha: 0.7)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppStyles.radiusSm,
        borderSide: BorderSide(color: AppColors.borderLight.withValues(alpha: 0.7)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppStyles.radiusSm,
        borderSide: const BorderSide(color: Color(0xFF8A94A6), width: 1.4),
      ),
    ),
    extensions: <ThemeExtension<dynamic>>[
      AppThemeExtension(
        cardBackground: AppColors.surfaceLight,
        cardBorder: AppColors.borderLight,
        secondaryText: AppColors.textSecondaryLight,
        sidebarItemBackground: const Color(0xFFF1F5F9),
        subtleDivider: AppColors.textPrimaryLight.withValues(alpha: 0.1),
        selectedIndicator: AppColors.primary,
        hoverOverlay: AppColors.primary.withValues(alpha: 0.16),
        mutedText: const Color(0xFF64748B),
        sidebarText: const Color(0xFF282828),
        sidebarMutedText: const Color(0xFF3A3A3A),
        inputFillNormal: const Color(0xFFF8FAFC),
        inputHoverBackground: const Color(0xFFF1F2F4),
        inputActiveBackground: const Color(0xFFEDEFF2),
        placeholderText: const Color(0xFF94A3B8),
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
    cardTheme: CardThemeData(
      color: AppColors.surfaceDark,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: AppStyles.radiusMd),
      shadowColor: Colors.black.withValues(alpha: 0.28),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surfaceDark,
      shape: RoundedRectangleBorder(borderRadius: AppStyles.radiusLg),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF222222),
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.42)),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: AppStyles.radiusSm,
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppStyles.radiusSm,
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppStyles.radiusSm,
        borderSide: const BorderSide(color: Color(0xFF5E6673), width: 1.4),
      ),
    ),
    extensions: <ThemeExtension<dynamic>>[
      AppThemeExtension(
        cardBackground: AppColors.surfaceDark,
        cardBorder: AppColors.borderDark,
        secondaryText: AppColors.textSecondaryDark,
        sidebarItemBackground: AppColors.primary.withValues(alpha: 0.16),
        subtleDivider: Colors.white.withValues(alpha: 0.1),
        selectedIndicator: AppColors.primary,
        hoverOverlay: AppColors.primary.withValues(alpha: 0.16),
        mutedText: Colors.white.withValues(alpha: 0.64),
        sidebarText: Colors.white.withValues(alpha: 0.92),
        sidebarMutedText: Colors.white.withValues(alpha: 0.76),
        inputFillNormal: const Color(0xFF222222),
        inputHoverBackground: const Color.fromARGB(255, 35, 35, 35),
        inputActiveBackground: const Color.fromARGB(255, 35, 35, 35),
        placeholderText: Colors.white.withValues(alpha: 0.42),
      ),
    ],
  );
}
