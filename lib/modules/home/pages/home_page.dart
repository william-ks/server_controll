import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/routes/routes_config.dart';
import '../../../config/theme/app_theme_extension.dart';
import '../../../layout/default_layout.dart';
import '../../../layout/widgets/server_status_badge.dart';
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
      title: 'Dashboard do Servidor',
      currentRoute: AppRoutes.home,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            const double spacing = 20.0;
            const double minCardWidth = 240.0;
            int crossAxisCount = (constraints.maxWidth / minCardWidth).floor();
            if (crossAxisCount < 1) crossAxisCount = 1;
            if (crossAxisCount > 3) crossAxisCount = 3;

            final double cardWidth =
                (constraints.maxWidth - (spacing * (crossAxisCount - 1))) /
                crossAxisCount;

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Visão Geral',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                      ),
                      if (crossAxisCount == 1)
                        ServerStatusBadge(lifecycle: runtime.lifecycle),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Cartões Principais (Status, Uptime, Players)
                  Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: [
                      _buildSummaryCard(
                        context: context,
                        width: cardWidth,
                        child: StatusCard(lifecycle: runtime.lifecycle),
                      ),
                      _buildSummaryCard(
                        context: context,
                        width: cardWidth,
                        child: UptimeCard(
                          uptime: runtime.uptime,
                          lifecycle: runtime.lifecycle,
                        ),
                      ),
                      _buildSummaryCard(
                        context: context,
                        width: cardWidth,
                        child: ActivePlayersCard(
                          activePlayers: runtime.activePlayers,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: spacing),

                  // Cartão Expandido: Online Players
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: ext.cardBackground,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: ext.cardBorder.withValues(alpha: 0.5),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Jogadores Online',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                        const SizedBox(height: 16),
                        OnlinePlayersStripCard(players: runtime.onlinePlayers),
                      ],
                    ),
                  ),
                  const SizedBox(height: spacing),

                  // Cartão Expandido: PVP Control
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: ext.cardBackground,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: ext.cardBorder.withValues(alpha: 0.5),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: PvpControlCard(
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
                  ),
                  const SizedBox(height: 32),

                  // Ações do Servidor
                  ServerActionsBar(
                    lifecycle: runtime.lifecycle,
                    canStartServer: hasEssentials,
                    maintenanceActive: maintenanceState.snapshot.isActive,
                    onStart: actions.startServer,
                    onStop: actions.stopServer,
                    onRestart: actions.restartServer,
                    onKickPlayers: () => showDialog<void>(
                      context: context,
                      builder: (_) => const KickPlayersModal(),
                    ),
                    onMaintenance: () => showDialog<void>(
                      context: context,
                      builder: (_) => const MaintenanceModeModal(),
                    ),
                  ),

                  // Erros e avisos
                  if (!hasEssentials) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.errorContainer.withValues(alpha: 0.5),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.errorContainer,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Defina o Path do servidor, Comando do Java e Nome do arquivo JAR em "Config" para iniciar.',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (runtime.lastError != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Erro Crítico: ${runtime.lastError}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required BuildContext context,
    required double width,
    required Widget child,
  }) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    return Container(
      width: width,
      height: 110,
      decoration: BoxDecoration(
        color: ext.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ext.cardBorder.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: child,
    );
  }
}
