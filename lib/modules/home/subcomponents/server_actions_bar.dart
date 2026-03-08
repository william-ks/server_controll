import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../backup/subcomponents/manual_server_backup_flow.dart';
import '../../../../components/buttons/app_button.dart';
import '../../../../components/shared/app_variant.dart';
import '../../../../models/server_lifecycle_state.dart';

class ServerActionsBar extends ConsumerWidget {
  const ServerActionsBar({
    super.key,
    required this.lifecycle,
    required this.canStartServer,
    required this.maintenanceActive,
    required this.onStart,
    required this.onStop,
    required this.onRestart,
    required this.onKickPlayers,
    required this.onMaintenance,
  });

  final ServerLifecycleState lifecycle;
  final bool canStartServer;
  final bool maintenanceActive;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onRestart;
  final VoidCallback onKickPlayers;
  final VoidCallback onMaintenance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = lifecycle == ServerLifecycleState.online;
    final isStarting =
        lifecycle == ServerLifecycleState.starting ||
        lifecycle == ServerLifecycleState.restarting;
    final isOffline = lifecycle == ServerLifecycleState.offline;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (!isOnline && !isStarting)
          AppButton(
            label: 'Iniciar servidor',
            onPressed: canStartServer ? onStart : null,
            isDisabled: !canStartServer,
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
        ManualServerBackupButton(enabled: isOffline),
        AppButton(
          label: 'Desconectar Jogadores',
          onPressed: isOnline ? onKickPlayers : null,
          isDisabled: !isOnline,
          variant: AppVariant.info,
          icon: Icons.person_off_rounded,
        ),
        AppButton(
          label: maintenanceActive ? 'Manutenção (ativa)' : 'Manutenção',
          onPressed: onMaintenance,
          variant: AppVariant.warning,
          icon: Icons.build_circle_outlined,
        ),
      ],
    );
  }
}
