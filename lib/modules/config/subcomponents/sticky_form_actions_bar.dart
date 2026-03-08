import 'package:flutter/material.dart';

import '../../../components/buttons/app_button.dart';
import '../../../components/shared/app_variant.dart';

class StickyFormActionsBar extends StatelessWidget {
  const StickyFormActionsBar({
    super.key,
    required this.onSave,
    this.onCancel,
    required this.saveEnabled,
    required this.saveLoading,
    this.helperText,
  });

  final VoidCallback? onSave;
  final VoidCallback? onCancel;
  final bool saveEnabled;
  final bool saveLoading;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (onCancel != null)
                AppButton(
                  label: 'Cancelar',
                  onPressed: onCancel,
                  variant: AppVariant.danger,
                  transparent: true,
                  icon: Icons.close_rounded,
                ),
              if (onCancel != null) const SizedBox(width: 10),
              AppButton(
                label: 'Salvar',
                onPressed: onSave,
                isLoading: saveLoading,
                isDisabled: !saveEnabled || saveLoading,
                variant: AppVariant.success,
                icon: Icons.save_rounded,
              ),
            ],
          ),
          if (helperText != null && helperText!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              helperText!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
              textAlign: TextAlign.right,
            ),
          ],
        ],
      ),
    );
  }
}
