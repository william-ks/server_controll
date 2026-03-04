import 'package:flutter/material.dart';

class AppSelectItem<T> {
  const AppSelectItem({required this.value, required this.label});

  final T value;
  final String label;
}

class AppSelect<T> extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: errorText,
      ),
      items: items
          .map(
            (item) => DropdownMenuItem<T>(
              value: item.value,
              child: Text(item.label),
            ),
          )
          .toList(),
      onChanged: enabled ? onChanged : null,
    );
  }
}
