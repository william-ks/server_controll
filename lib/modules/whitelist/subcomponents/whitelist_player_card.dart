import 'package:flutter/material.dart';

import '../models/whitelist_player.dart';
import 'whitelist_player_avatar.dart';

class WhitelistPlayerCard extends StatelessWidget {
  const WhitelistPlayerCard({
    super.key,
    required this.player,
    required this.onEdit,
    required this.onDelete,
  });

  final WhitelistPlayer player;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final pending = player.isPending;
    final color = pending ? Theme.of(context).colorScheme.tertiary : Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          WhitelistPlayerAvatar(iconPath: player.iconPath),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(player.nickname, style: Theme.of(context).textTheme.titleMedium),
                Text(player.uuid ?? 'UUID pendente', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(
                  pending ? 'Pendente' : 'Adicionado',
                  style: TextStyle(color: color, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_rounded)),
          IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline_rounded)),
        ],
      ),
    );
  }
}
