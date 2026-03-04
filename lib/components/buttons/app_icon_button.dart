import 'package:flutter/material.dart';

import '../shared/app_variant.dart';

class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.variant = AppVariant.primary,
    this.transparent = false,
    this.isLoading = false,
    this.isDisabled = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final AppVariant variant;
  final bool transparent;
  final bool isLoading;
  final bool isDisabled;

  @override
  Widget build(BuildContext context) {
    final color = AppVariantPalette.resolve(variant);

    return IconButton(
      onPressed: isDisabled || isLoading ? null : onPressed,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: transparent ? Colors.transparent : color,
        foregroundColor: transparent ? color : Colors.white,
        side: transparent ? BorderSide(color: color) : BorderSide.none,
      ),
      icon: isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon),
    );
  }
}

