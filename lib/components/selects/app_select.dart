import 'package:flutter/material.dart';

import '../../config/theme/app_theme_extension.dart';

class AppSelectItem<T> {
  const AppSelectItem({required this.value, required this.label});

  final T value;
  final String label;
}

class AppSelect<T> extends StatefulWidget {
  const AppSelect({
    super.key,
    this.label,
    this.hint,
    required this.items,
    this.value,
    this.errorText,
    this.enabled = true,
    this.onChanged,
  });

  final String? label;
  final String? hint;
  final List<AppSelectItem<T>> items;
  final T? value;
  final String? errorText;
  final bool enabled;
  final ValueChanged<T?>? onChanged;

  @override
  State<AppSelect<T>> createState() => _AppSelectState<T>();
}

class _AppSelectState<T> extends State<AppSelect<T>> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>();
    final hasValue = widget.value != null;
    final hasActiveState = _focused || hasValue;

    return Focus(
      onFocusChange: (hasFocus) => setState(() => _focused = hasFocus),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: DropdownButtonFormField<T>(
          isExpanded: true,
          initialValue: widget.value,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            errorText: widget.errorText,
            fillColor: hasActiveState
                ? ext?.inputActiveBackground
                : (_hovered ? ext?.inputHoverBackground : ext?.inputFillNormal),
            hintStyle: TextStyle(color: ext?.placeholderText),
          ),
          items: widget.items
              .map(
                (item) => DropdownMenuItem<T>(
                  value: item.value,
                  child: Text(item.label),
                ),
              )
              .toList(),
          onChanged: widget.enabled ? widget.onChanged : null,
        ),
      ),
    );
  }
}
