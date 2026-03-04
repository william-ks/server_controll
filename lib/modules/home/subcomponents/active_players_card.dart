import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';

class ActivePlayersCard extends StatelessWidget {
  const ActivePlayersCard({super.key, required this.activePlayers});

  final int activePlayers;

  @override
  Widget build(BuildContext context) {
    final hasPlayers = activePlayers > 0;
    final color = hasPlayers ? AppColors.primary : AppColors.neutral;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Jogadores ativos', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          Text(
            '$activePlayers',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
