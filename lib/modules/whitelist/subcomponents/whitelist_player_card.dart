import 'package:flutter/material.dart';

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
    final statusColor = isOnline ? Colors.green : Colors.red.shade300;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: noUuid
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          WhitelistPlayerAvatar(iconPath: player.iconPath),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(player.nickname, style: Theme.of(context).textTheme.titleMedium)),
                    _StatusChip(label: isOnline ? 'ONLINE' : 'OFFLINE', color: statusColor),
                  ],
                ),
                const SizedBox(height: 2),
                Text(player.uuid?.trim().isNotEmpty == true ? player.uuid! : 'ID vazio',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(
                  player.isPending ? 'PENDENTE' : 'ADICIONADO',
                  style: TextStyle(
                    color: player.isPending ? Theme.of(context).colorScheme.tertiary : Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: Icon(Icons.edit_rounded, color: Theme.of(context).colorScheme.secondary),
          ),
          IconButton(
            onPressed: onDelete,
            icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade300),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11),
      ),
    );
  }
}
