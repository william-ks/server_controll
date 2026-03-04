import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_theme_extension.dart';

class ActivePlayersCard extends StatelessWidget {
  const ActivePlayersCard({super.key, required this.activePlayers});

  final int activePlayers;

  @override
  Widget build(BuildContext context) {
    final hasPlayers = activePlayers > 0;
    final color = hasPlayers ? AppColors.primary : AppColors.neutral;
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ext.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ext.cardBorder.withValues(alpha: 0.65)),
      ),
      child: Row(
        children: [
          const Icon(Icons.group_rounded, color: AppColors.primary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Jogadores ativos', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 6),
                Text(
                  '$activePlayers',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
