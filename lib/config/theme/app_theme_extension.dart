import 'package:flutter/material.dart';

@immutable
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  final Color cardBackground;
  final Color cardBorder;
  final Color secondaryText;
  final Color sidebarItemBackground;

  const AppThemeExtension({
    required this.cardBackground,
    required this.cardBorder,
    required this.secondaryText,
    required this.sidebarItemBackground,
  });

  @override
  AppThemeExtension copyWith({
    Color? cardBackground,
    Color? cardBorder,
    Color? secondaryText,
    Color? sidebarItemBackground,
  }) {
    return AppThemeExtension(
      cardBackground: cardBackground ?? this.cardBackground,
      cardBorder: cardBorder ?? this.cardBorder,
      secondaryText: secondaryText ?? this.secondaryText,
      sidebarItemBackground: sidebarItemBackground ?? this.sidebarItemBackground,
    );
  }

  @override
  AppThemeExtension lerp(ThemeExtension<AppThemeExtension>? other, double t) {
    if (other is! AppThemeExtension) {
      return this;
    }
    return AppThemeExtension(
      cardBackground: Color.lerp(cardBackground, other.cardBackground, t) ?? cardBackground,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t) ?? cardBorder,
      secondaryText: Color.lerp(secondaryText, other.secondaryText, t) ?? secondaryText,
      sidebarItemBackground:
          Color.lerp(sidebarItemBackground, other.sidebarItemBackground, t) ?? sidebarItemBackground,
    );
  }
}

