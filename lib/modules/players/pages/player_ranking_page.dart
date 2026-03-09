import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/routes/routes_config.dart';

import '../../../layout/default_layout.dart';
import '../providers/player_playtime_provider.dart';
import '../subcomponents/player_ranking_dashboard.dart';

class PlayerRankingPage extends ConsumerWidget {
  const PlayerRankingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playtimeState = ref.watch(playerPlaytimeProvider);
    final playtimeNotifier = ref.read(playerPlaytimeProvider.notifier);

    return DefaultLayout(
      title: 'Ranking de Players',
      currentRoute: AppRoutes.playersRanking,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: SingleChildScrollView(
          child: PlayerRankingDashboard(
            state: playtimeState,
            onRefresh: playtimeNotifier.refresh,
            onToggleShowAll: playtimeNotifier.toggleShowFullRanking,
            onPeriodChanged: playtimeNotifier.setRankingPeriod,
          ),
        ),
      ),
    );
  }
}
