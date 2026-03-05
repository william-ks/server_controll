import 'package:flutter/material.dart';

import '../shared/app_variant.dart';

class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.title,
    this.description,
    this.icon,
    this.trailing,
    this.variant = AppVariant.info,
    this.color,
    this.padding,
    this.borderRadius = 10,
    this.titleStyle,
    this.descriptionStyle,
  });

  final String title;
  final String? description;
  final IconData? icon;
  final Widget? trailing;
  final AppVariant variant;
  final Color? color;
  final EdgeInsets? padding;
  final double borderRadius;
  final TextStyle? titleStyle;
  final TextStyle? descriptionStyle;

  @override
  Widget build(BuildContext context) {
    final baseColor = color ?? AppVariantPalette.resolve(variant);
    final hasDescription =
        description != null && description!.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: baseColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: baseColor.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: baseColor.withValues(alpha: 0.94)),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                      titleStyle ??
                      Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: baseColor.withValues(alpha: 0.94),
                      ),
                ),
                if (hasDescription) ...[
                  const SizedBox(height: 4),
                  Text(
                    description!,
                    style:
                        descriptionStyle ??
                        Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w400,
                          color: baseColor.withValues(alpha: 0.78),
                        ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}
