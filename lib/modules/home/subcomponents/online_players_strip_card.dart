import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';

class OnlinePlayersStripCard extends StatelessWidget {
  const OnlinePlayersStripCard({super.key, required this.players});

  final List<String> players;

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) {
      return Text(
        '0 jogadores conectados',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.neutral,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: players.map((name) => _PlayerBadge(name: name)).toList(),
    );
  }
}

class _PlayerBadge extends StatelessWidget {
  const _PlayerBadge({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.only(right: 6),
            decoration: const BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
            ),
          ),
          Text(
            name,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
