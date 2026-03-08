import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/routes/routes_config.dart';
import '../../../config/theme/app_styles.dart';
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
