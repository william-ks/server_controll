import 'package:flutter/material.dart';

@immutable
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  final Color cardBackground;
  final Color cardBorder;
  final Color secondaryText;
  final Color sidebarItemBackground;
  final Color subtleDivider;
  final Color selectedIndicator;
  final Color hoverOverlay;
  final Color mutedText;
  final Color sidebarText;
  final Color sidebarMutedText;
  final Color inputFillNormal;
  final Color inputFillActive;
  final Color placeholderText;

  const AppThemeExtension({
    required this.cardBackground,
    required this.cardBorder,
    required this.secondaryText,
    required this.sidebarItemBackground,
    required this.subtleDivider,
    required this.selectedIndicator,
    required this.hoverOverlay,
    required this.mutedText,
    required this.sidebarText,
    required this.sidebarMutedText,
    required this.inputFillNormal,
    required this.inputFillActive,
    required this.placeholderText,
  });

  @override
  AppThemeExtension copyWith({
    Color? cardBackground,
    Color? cardBorder,
    Color? secondaryText,
    Color? sidebarItemBackground,
    Color? subtleDivider,
    Color? selectedIndicator,
    Color? hoverOverlay,
    Color? mutedText,
    Color? sidebarText,
    Color? sidebarMutedText,
    Color? inputFillNormal,
    Color? inputFillActive,
    Color? placeholderText,
  }) {
    return AppThemeExtension(
      cardBackground: cardBackground ?? this.cardBackground,
      cardBorder: cardBorder ?? this.cardBorder,
      secondaryText: secondaryText ?? this.secondaryText,
      sidebarItemBackground: sidebarItemBackground ?? this.sidebarItemBackground,
      subtleDivider: subtleDivider ?? this.subtleDivider,
      selectedIndicator: selectedIndicator ?? this.selectedIndicator,
      hoverOverlay: hoverOverlay ?? this.hoverOverlay,
      mutedText: mutedText ?? this.mutedText,
      sidebarText: sidebarText ?? this.sidebarText,
      sidebarMutedText: sidebarMutedText ?? this.sidebarMutedText,
      inputFillNormal: inputFillNormal ?? this.inputFillNormal,
      inputFillActive: inputFillActive ?? this.inputFillActive,
      placeholderText: placeholderText ?? this.placeholderText,
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
      subtleDivider: Color.lerp(subtleDivider, other.subtleDivider, t) ?? subtleDivider,
      selectedIndicator: Color.lerp(selectedIndicator, other.selectedIndicator, t) ?? selectedIndicator,
      hoverOverlay: Color.lerp(hoverOverlay, other.hoverOverlay, t) ?? hoverOverlay,
      mutedText: Color.lerp(mutedText, other.mutedText, t) ?? mutedText,
      sidebarText: Color.lerp(sidebarText, other.sidebarText, t) ?? sidebarText,
      sidebarMutedText: Color.lerp(sidebarMutedText, other.sidebarMutedText, t) ?? sidebarMutedText,
      inputFillNormal: Color.lerp(inputFillNormal, other.inputFillNormal, t) ?? inputFillNormal,
      inputFillActive: Color.lerp(inputFillActive, other.inputFillActive, t) ?? inputFillActive,
      placeholderText: Color.lerp(placeholderText, other.placeholderText, t) ?? placeholderText,
    );
  }
}
