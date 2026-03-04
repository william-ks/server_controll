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
    required this.onKickPlayers,
  });

  final ServerLifecycleState lifecycle;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onRestart;
  final VoidCallback onBackup;
  final VoidCallback onKickPlayers;

  @override
  Widget build(BuildContext context) {
    final isOnline = lifecycle == ServerLifecycleState.online;
    final isStarting = lifecycle == ServerLifecycleState.starting || lifecycle == ServerLifecycleState.restarting;
    final isOffline = lifecycle == ServerLifecycleState.offline;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (!isOnline && !isStarting)
          AppButton(
            label: 'Iniciar servidor',
            onPressed: onStart,
            variant: AppVariant.primary,
            icon: Icons.play_arrow_rounded,
          ),
        if (isOnline || isStarting)
          AppButton(
            label: 'Desligar servidor',
            onPressed: isOnline ? onStop : null,
            isDisabled: !isOnline,
            variant: AppVariant.danger,
            icon: Icons.stop_rounded,
          ),
        if (isOnline || isStarting)
          AppButton(
            label: 'Reiniciar servidor',
            onPressed: isOnline ? onRestart : null,
            isDisabled: !isOnline,
            variant: AppVariant.warning,
            icon: Icons.restart_alt_rounded,
          ),
        AppButton(
          label: 'Backup',
          onPressed: isOffline ? onBackup : null,
          isDisabled: !isOffline,
          variant: AppVariant.secondary,
          icon: Icons.backup_rounded,
        ),
        AppButton(
          label: 'Desconectar Jogadores',
          onPressed: isOnline ? onKickPlayers : null,
          isDisabled: !isOnline,
          variant: AppVariant.info,
          icon: Icons.person_off_rounded,
        ),
      ],
    );
  }
}
