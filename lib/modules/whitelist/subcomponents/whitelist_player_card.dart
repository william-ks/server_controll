import 'package:flutter/material.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_theme_extension.dart';
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
    final scheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final statusColor = isOnline ? AppColors.success : scheme.onSurfaceVariant.withValues(alpha: 0.86);

    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.98),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: noUuid ? 0.18 : 0.1),
                blurRadius: noUuid ? 12 : 7,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 4,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 10),
              WhitelistPlayerAvatar(iconPath: player.iconPath, radius: 30),
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
                    Text(
                      'UUID: ${player.uuid?.trim().isNotEmpty == true ? player.uuid! : 'vazio'}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: ext.mutedText,
                          ),
                    ),
                    const SizedBox(height: 8),
                    _StatusChip(label: isOnline ? 'ONLINE' : 'OFFLINE', color: statusColor),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: onEdit,
                    icon: Icon(Icons.edit_rounded, color: AppColors.info.withValues(alpha: 0.9)),
                  ),
                  IconButton(
                    onPressed: onDelete,
                    icon: Icon(Icons.delete_outline_rounded, color: AppColors.danger.withValues(alpha: 0.72)),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (player.isPending)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.28)),
              ),
              child: Text(
                'PENDENTE',
                style: TextStyle(
                  color: AppColors.warning.withValues(alpha: 0.92),
                  fontWeight: FontWeight.w700,
                  fontSize: 10.5,
                ),
              ),
            ),
          ),
      ],
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
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
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
