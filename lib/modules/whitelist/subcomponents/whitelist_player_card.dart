import 'package:flutter/material.dart';

import '../../../config/theme/app_colors.dart';
import '../models/whitelist_player.dart';
import 'whitelist_player_avatar.dart';

class WhitelistPlayerCard extends StatelessWidget {
  const WhitelistPlayerCard({
    super.key,
    required this.player,
    required this.isOnline,
    required this.onEdit,
    required this.onDelete,
  });

  final WhitelistPlayer player;
  final bool isOnline;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final noUuid = player.uuid == null || player.uuid!.trim().isEmpty;
    final statusColor = isOnline ? AppColors.success : AppColors.danger.withValues(alpha: 0.85);
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: noUuid ? AppColors.secondary.withValues(alpha: 0.45) : Theme.of(context).dividerColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: noUuid ? 0.2 : 0.12),
            blurRadius: noUuid ? 12 : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WhitelistPlayerAvatar(iconPath: player.iconPath),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.nickname,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(player.uuid?.trim().isNotEmpty == true ? player.uuid! : 'UID vazio',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 8),
                _StatusChip(
                  label: isOnline ? 'ONLINE' : 'OFFLINE',
                  color: statusColor,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (player.isPending)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    'PENDENTE',
                    style: TextStyle(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: onEdit,
                    icon: Icon(Icons.edit_rounded, color: scheme.secondary),
                  ),
                  IconButton(
                    onPressed: onDelete,
                    icon: Icon(Icons.delete_outline_rounded, color: AppColors.danger.withValues(alpha: 0.8)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
