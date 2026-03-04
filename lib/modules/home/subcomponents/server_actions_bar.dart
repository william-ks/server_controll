import 'package:flutter/material.dart';

import '../../../../components/buttons/app_button.dart';
import '../../../../components/shared/app_variant.dart';
import '../../../../models/server_lifecycle_state.dart';

class ServerActionsBar extends StatelessWidget {
  const ServerActionsBar({
    super.key,
    required this.lifecycle,
    required this.onStart,
    required this.onStop,
    required this.onRestart,
    required this.onBackup,
  });

  final ServerLifecycleState lifecycle;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onRestart;
  final VoidCallback onBackup;

  @override
  Widget build(BuildContext context) {
    final isOnline = lifecycle == ServerLifecycleState.online;
    final isStarting = lifecycle == ServerLifecycleState.starting || lifecycle == ServerLifecycleState.restarting;

    if (!isOnline && !isStarting) {
      return Row(
        children: [
          AppButton(
            label: 'Iniciar servidor',
            onPressed: onStart,
            variant: AppVariant.primary,
            icon: Icons.play_arrow_rounded,
          ),
        ],
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        AppButton(
          label: 'Desligar servidor',
          onPressed: isOnline ? onStop : null,
          isDisabled: !isOnline,
          variant: AppVariant.danger,
          icon: Icons.stop_rounded,
        ),
        AppButton(
          label: 'Reiniciar servidor',
          onPressed: isOnline ? onRestart : null,
          isDisabled: !isOnline,
          variant: AppVariant.warning,
          icon: Icons.restart_alt_rounded,
        ),
        AppButton(
          label: 'Backup',
          onPressed: onBackup,
          variant: AppVariant.secondary,
          icon: Icons.backup_rounded,
        ),
      ],
    );
  }
}

