import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/routes/routes_config.dart';
import '../../../config/theme/app_theme_extension.dart';
import '../../../layout/default_layout.dart';
import '../../../modules/server/providers/server_runtime_provider.dart';
import '../providers/home_provider.dart';
import '../subcomponents/active_players_card.dart';
import '../subcomponents/server_actions_bar.dart';
import '../subcomponents/status_card.dart';
import '../subcomponents/uptime_card.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runtime = ref.watch(serverRuntimeProvider);
    final actions = ref.read(homeActionsProvider);
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

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
              Text('Bem-vindo ao MineControl', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                'Controle seu servidor Minecraft local com monitoramento em tempo real.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: MediaQuery.of(context).size.width > 1100 ? 3 : 1,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 3.5,
                children: [
                  StatusCard(lifecycle: runtime.lifecycle),
                  UptimeCard(uptime: runtime.uptime, lifecycle: runtime.lifecycle),
                  ActivePlayersCard(activePlayers: runtime.activePlayers),
                ],
              ),
              const SizedBox(height: 16),
              ServerActionsBar(
                lifecycle: runtime.lifecycle,
                onStart: actions.startServer,
                onStop: actions.stopServer,
                onRestart: actions.restartServer,
                onBackup: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Backup será implementado em task futura.')),
                  );
                },
              ),
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
}
