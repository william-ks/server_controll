import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_theme_extension.dart';

class OnlinePlayersStripCard extends StatelessWidget {
  const OnlinePlayersStripCard({super.key, required this.players});

  final List<String> players;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ext.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ext.cardBorder.withValues(alpha: 0.65)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.badge_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'JOGADORES ONLINE',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '${players.length}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: players.isEmpty ? AppColors.neutral : AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (players.isEmpty)
            Text(
              '0 jogadores conectados',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.neutral),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: players.map((name) => _PlayerBadge(name: name)).toList(),
            ),
        ],
      ),
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
            decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
          ),
          Text(
            name,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
