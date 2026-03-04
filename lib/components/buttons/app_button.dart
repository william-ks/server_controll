import 'package:flutter/material.dart';

import '../shared/app_variant.dart';

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppVariant.primary,
    this.icon,
    this.transparent = false,
    this.isLoading = false,
    this.isDisabled = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppVariant variant;
  final IconData? icon;
  final bool transparent;
  final bool isLoading;
  final bool isDisabled;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final color = AppVariantPalette.resolve(variant);
    final foreground = transparent ? color : Colors.white;

    final child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading)
          SizedBox(
            height: 16,
            width: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(foreground),
            ),
          ),
        if (!isLoading && icon != null) ...[
          Icon(icon, size: 18),
        ],
        if (isLoading || icon != null) const SizedBox(width: 8),
        Text(label),
      ],
    );

    final button = ElevatedButton(
      onPressed: isDisabled || isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: transparent ? Colors.transparent : color,
        foregroundColor: foreground,
        disabledBackgroundColor: color.withValues(alpha: 0.25),
        disabledForegroundColor: foreground.withValues(alpha: 0.7),
        elevation: transparent ? 0 : 1,
        side: transparent ? BorderSide(color: color) : BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: child,
    );

    if (expand) {
      return SizedBox(width: double.infinity, child: button);
    }

    return button;
  }
}

