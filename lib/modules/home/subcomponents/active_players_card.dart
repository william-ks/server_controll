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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Icon(Icons.group_rounded, color: ext.mutedText, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'JOGADORES ATIVOS',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: ext.mutedText,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
        const Spacer(),
        Text(
          '$activePlayers',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
