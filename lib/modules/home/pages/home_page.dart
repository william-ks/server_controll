import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/routes/routes_config.dart';
import '../../../config/theme/app_theme_extension.dart';
import '../../../layout/default_layout.dart';
import '../../../models/server_lifecycle_state.dart';
import '../../../modules/server/providers/server_runtime_provider.dart';
import '../../config/providers/config_files_provider.dart';
import '../../maintenance/providers/maintenance_provider.dart';
import '../providers/home_provider.dart';
import '../providers/pvp_control_provider.dart';
import '../subcomponents/active_players_card.dart';
import '../subcomponents/kick_players_modal.dart';
import '../subcomponents/maintenance_mode_modal.dart';
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
    final maintenanceState = ref.watch(maintenanceProvider);
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
          height: double.infinity,
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              const metricSpacing = 12.0;
              const metricMinWidth = 220.0;
              final hideActivePlayersCard =
                  constraints.maxWidth <
                  (metricMinWidth * 3) + (metricSpacing * 2);

              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!hideActivePlayersCard)
                        Wrap(
                          spacing: metricSpacing,
                          runSpacing: metricSpacing,
                          children: [
                            _buildMetricTile(
                              child: StatusCard(lifecycle: runtime.lifecycle),
                              maxWidth: 360,
                            ),
                            _buildMetricTile(
                              child: UptimeCard(
                                uptime: runtime.uptime,
                                lifecycle: runtime.lifecycle,
                              ),
                              maxWidth: 360,
                            ),
                            _buildMetricTile(
                              child: ActivePlayersCard(
                                activePlayers: runtime.activePlayers,
                              ),
                              maxWidth: 360,
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: _buildMetricTile(
                                child: StatusCard(lifecycle: runtime.lifecycle),
                                maxWidth: double.infinity,
                              ),
                            ),
                            const SizedBox(width: metricSpacing),
                            Expanded(
                              child: _buildMetricTile(
                                child: UptimeCard(
                                  uptime: runtime.uptime,
                                  lifecycle: runtime.lifecycle,
                                ),
                                maxWidth: double.infinity,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 12),
                      OnlinePlayersStripCard(players: runtime.onlinePlayers),
                      const SizedBox(height: 12),
                      PvpControlCard(
                        enabled: pvpState.enabled,
                        interactive:
                            runtime.lifecycle == ServerLifecycleState.online &&
                            !pvpState.updating,
                        onChanged: (value) async {
                          final ok = await pvpNotifier.setDesiredWithRuntime(
                            value,
                          );
                          if (!ok && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Falha ao aplicar PVP no servidor.',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      ServerActionsBar(
                        lifecycle: runtime.lifecycle,
                        canStartServer: hasEssentials,
                        maintenanceActive: maintenanceState.snapshot.isActive,
                        onStart: actions.startServer,
                        onStop: actions.stopServer,
                        onRestart: actions.restartServer,
                        onKickPlayers: () {
                          showDialog<void>(
                            context: context,
                            builder: (_) => const KickPlayersModal(),
                          );
                        },
                        onMaintenance: () {
                          showDialog<void>(
                            context: context,
                            builder: (_) => const MaintenanceModeModal(),
                          );
                        },
                      ),
                      if (!hasEssentials) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Defina Path do servidor, Comando do Java e Nome do file server em Config > Arquivos para iniciar.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.error,
                              ),
                        ),
                      ],
                      if (runtime.lastError != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Erro: ${runtime.lastError}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTile({required Widget child, required double maxWidth}) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: 220,
        maxWidth: maxWidth,
        minHeight: 96,
        maxHeight: 112,
      ),
      child: SizedBox(height: 104, child: child),
    );
  }
}
