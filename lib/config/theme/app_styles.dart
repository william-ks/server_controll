import 'package:flutter/material.dart';

class AppStyles {
  AppStyles._();

  static const double spacingXs = 4;
  static const double spacingSm = 8;
  static const double spacingMd = 16;
  static const double spacingLg = 24;

  static const EdgeInsets pagePadding = EdgeInsets.all(spacingMd);

  static BorderRadius get radiusSm => BorderRadius.circular(8);
  static BorderRadius get radiusMd => BorderRadius.circular(10);
  static BorderRadius get radiusLg => BorderRadius.circular(12);
  static BorderRadius get radiusFull => BorderRadius.circular(999);

  static List<BoxShadow> softShadow({double opacity = 0.16}) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: opacity),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];
}
