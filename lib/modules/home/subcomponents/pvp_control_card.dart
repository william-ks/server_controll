import 'package:flutter/material.dart';

import '../../../config/theme/app_theme_extension.dart';

class PvpControlCard extends StatelessWidget {
  const PvpControlCard({
    super.key,
    required this.enabled,
    required this.interactive,
    required this.onChanged,
  });

  final bool enabled;
  final bool interactive;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PVP',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                'Controla o PVP do servidor',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: ext.mutedText),
              ),
              const SizedBox(height: 6),
              Text(
                enabled ? 'PVP Ativo' : 'PVP Desativado',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: enabled
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Switch.adaptive(
          value: enabled,
          onChanged: interactive ? onChanged : null,
          activeTrackColor: Theme.of(context).colorScheme.primary,
        ),
      ],
    );
  }
}
