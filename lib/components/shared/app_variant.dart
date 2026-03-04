import 'package:flutter/material.dart';

import '../../config/theme/app_colors.dart';

enum AppVariant { primary, secondary, success, info, warning, danger }

class AppVariantPalette {
  AppVariantPalette._();

  static Color resolve(AppVariant variant) {
    return switch (variant) {
      AppVariant.primary => AppColors.primary,
      AppVariant.secondary => AppColors.secondary,
      AppVariant.success => AppColors.success,
      AppVariant.info => AppColors.info,
      AppVariant.warning => AppColors.warning,
      AppVariant.danger => AppColors.danger,
    };
  }
}

