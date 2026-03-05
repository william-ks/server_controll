import 'package:flutter/material.dart';

import '../shared/app_variant.dart';

enum AppButtonType { button, icon, textIcon, textButton }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppVariant.primary,
    this.icon,
    this.type = AppButtonType.button,
    this.transparent = false,
    this.isLoading = false,
    this.isDisabled = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppVariant variant;
  final IconData? icon;
  final AppButtonType type;
  final bool transparent;
  final bool isLoading;
  final bool isDisabled;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final baseColor = AppVariantPalette.resolve(variant);
    final requestedType = type == AppButtonType.button && icon != null ? AppButtonType.textIcon : type;
    final effectiveType = requestedType == AppButtonType.textIcon && icon == null ? AppButtonType.button : requestedType;
    final isTextButton = effectiveType == AppButtonType.textButton;
    final isIconButton = effectiveType == AppButtonType.icon;
    final foreground = (transparent || isTextButton) ? baseColor : Colors.white;

    final child = _ButtonChild(
      label: label,
      icon: icon,
      type: effectiveType,
      loading: isLoading,
      foreground: foreground,
    );

    final style = ButtonStyle(
      padding: WidgetStateProperty.all(
        isIconButton ? const EdgeInsets.all(11) : const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      ),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isIconButton ? 999 : 10),
        ),
      ),
      elevation: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) return 0;
        return (transparent || isTextButton) ? 0 : 1;
      }),
      side: WidgetStateProperty.resolveWith((states) {
        if (!transparent || isTextButton) return BorderSide.none;
        final alpha = states.contains(WidgetState.hovered) ? 0.95 : 0.7;
        return BorderSide(color: baseColor.withValues(alpha: alpha));
      }),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return (transparent || isTextButton) ? Colors.transparent : baseColor.withValues(alpha: 0.24);
        }
        if (isTextButton) {
          if (states.contains(WidgetState.hovered)) return baseColor.withValues(alpha: 0.08);
          if (states.contains(WidgetState.pressed)) return baseColor.withValues(alpha: 0.14);
          return Colors.transparent;
        }
        if (transparent) {
          if (states.contains(WidgetState.hovered)) return baseColor.withValues(alpha: 0.1);
          if (states.contains(WidgetState.pressed)) return baseColor.withValues(alpha: 0.18);
          return Colors.transparent;
        }
        if (states.contains(WidgetState.pressed)) return baseColor.withValues(alpha: 0.82);
        if (states.contains(WidgetState.hovered)) return baseColor.withValues(alpha: 0.92);
        return baseColor;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return foreground.withValues(alpha: 0.7);
        }
        return foreground;
      }),
    );

    final button = ElevatedButton(
      onPressed: isDisabled || isLoading ? null : onPressed,
      style: style,
      child: child,
    );

    if (expand) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}

class _ButtonChild extends StatelessWidget {
  const _ButtonChild({
    required this.label,
    required this.icon,
    required this.type,
    required this.loading,
    required this.foreground,
  });

  final String label;
  final IconData? icon;
  final AppButtonType type;
  final bool loading;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return SizedBox(
        height: 16,
        width: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(foreground),
        ),
      );
    }

    if (type == AppButtonType.icon) {
      return Icon(icon ?? Icons.circle, size: 18);
    }

    if (type == AppButtonType.textIcon && icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 8),
          Icon(icon, size: 18),
        ],
      );
    }

    return Text(label);
  }
}

