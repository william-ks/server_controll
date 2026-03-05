import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/routes/routes_config.dart';
import '../../../config/theme/app_theme_extension.dart';
import '../../../layout/default_layout.dart';
import '../../../models/server_lifecycle_state.dart';
import '../../backup/providers/backups_provider.dart';
import '../../backup/services/backup_service.dart';
import '../../config/providers/config_files_provider.dart';
import '../../../modules/server/providers/server_runtime_provider.dart';
import '../providers/home_provider.dart';
import '../providers/pvp_control_provider.dart';
import '../subcomponents/active_players_card.dart';
import '../subcomponents/kick_players_modal.dart';
import '../subcomponents/manual_backup_modal.dart';
import '../subcomponents/online_players_strip_card.dart';
import '../subcomponents/pvp_control_card.dart';
import '../subcomponents/server_actions_bar.dart';
import '../subcomponents/status_card.dart';
import '../subcomponents/uptime_card.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runtime = ref.watch(serverRuntimeProvider);
    final actions = ref.read(homeActionsProvider);
    final pvpState = ref.watch(pvpControlProvider);
    final pvpNotifier = ref.read(pvpControlProvider.notifier);
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final config = ref.watch(configFilesProvider);
    final hasEssentials =
        config.serverPath.trim().isNotEmpty &&
        config.javaCommand.trim().isNotEmpty &&
        config.fileServerName.trim().isNotEmpty;

    return DefaultLayout(
      title: 'MineControl',
      currentRoute: AppRoutes.home,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ext.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ext.cardBorder.withValues(alpha: 0.7)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: MediaQuery.of(context).size.width > 1100
                    ? 3
                    : 1,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 3.5,
                children: [
                  StatusCard(lifecycle: runtime.lifecycle),
                  UptimeCard(
                    uptime: runtime.uptime,
                    lifecycle: runtime.lifecycle,
                  ),
                  ActivePlayersCard(activePlayers: runtime.activePlayers),
                ],
              ),
              const SizedBox(height: 12),
              OnlinePlayersStripCard(players: runtime.onlinePlayers),
              const SizedBox(height: 12),
              PvpControlCard(
                enabled: pvpState.enabled,
                interactive: runtime.lifecycle == ServerLifecycleState.online,
                onChanged: (value) => pvpNotifier.setDesired(value),
              ),
              const SizedBox(height: 16),
              ServerActionsBar(
                lifecycle: runtime.lifecycle,
                canStartServer: hasEssentials,
                onStart: actions.startServer,
                onStop: actions.stopServer,
                onRestart: actions.restartServer,
                onBackup: () {
                  _runManualBackup(context, ref);
                },
                onKickPlayers: () {
                  showDialog<void>(
                    context: context,
                    builder: (_) => const KickPlayersModal(),
                  );
                },
              ),
              if (!hasEssentials) ...[
                const SizedBox(height: 10),
                Text(
                  'Defina Path do servidor, Comando do Java e Nome do file server em Config > Arquivos para iniciar.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              if (runtime.lastError != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Erro: ${runtime.lastError}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _runManualBackup(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const ManualBackupConfirmModal(),
    );
    if (confirmed != true || !context.mounted) return;

    final controller = BackupTaskController();
    final result = await showDialog<ManualBackupResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ManualBackupProgressModal(controller: controller),
    );

    if (!context.mounted || result == null) return;
    final message = result.message;
    if (message == null || message.trim().isEmpty) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
    if (result.type == ManualBackupResultType.success) {
      await ref.read(backupsProvider.notifier).load();
    }
  }
}
