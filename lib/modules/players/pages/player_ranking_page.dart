import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/routes/routes_config.dart';
import '../../../config/theme/app_styles.dart';
import '../../../layout/default_layout.dart';
import '../../whitelist/subcomponents/player_playtime_panel.dart';
import '../providers/player_playtime_provider.dart';

class PlayerRankingPage extends ConsumerWidget {
  const PlayerRankingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playtimeState = ref.watch(playerPlaytimeProvider);
    final playtimeNotifier = ref.read(playerPlaytimeProvider.notifier);

    return DefaultLayout(
      title: 'Ranking de Players',
      currentRoute: AppRoutes.players,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: AppStyles.radiusLg,
            border: Border.all(color: Theme.of(context).dividerColor),
            boxShadow: AppStyles.softShadow(opacity: 0.18),
          ),
          padding: const EdgeInsets.all(16),
          child: PlayerPlaytimePanel(
            state: playtimeState,
            onRefresh: playtimeNotifier.refresh,
            onSelectPlayer: (playerId) {
              playtimeNotifier.selectPlayer(playerId);
            },
          ),
        ),
      ),
    );
  }
}
