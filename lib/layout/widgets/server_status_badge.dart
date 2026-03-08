import 'package:flutter/material.dart';

import '../../config/theme/app_colors.dart';
import '../../models/server_lifecycle_state.dart';

class ServerStatusBadge extends StatelessWidget {
  const ServerStatusBadge({
    super.key,
    required this.lifecycle,
    this.compact = false,
  });

  final ServerLifecycleState lifecycle;
  final bool compact;

  Color _color() {
    return switch (lifecycle) {
      ServerLifecycleState.offline => AppColors.neutral,
      ServerLifecycleState.starting => AppColors.primary,
      ServerLifecycleState.online => AppColors.success,
      ServerLifecycleState.stopping => AppColors.danger,
      ServerLifecycleState.restarting => AppColors.primary,
      ServerLifecycleState.error => AppColors.danger,
    };
  }

  String _label() {
    return switch (lifecycle) {
      ServerLifecycleState.offline => 'Offline',
      ServerLifecycleState.starting => 'Iniciando',
      ServerLifecycleState.online => 'Online',
      ServerLifecycleState.stopping => 'Desligando',
      ServerLifecycleState.restarting => 'Reiniciando',
      ServerLifecycleState.error => 'Erro',
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 6 : 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 7 : 8,
            height: compact ? 7 : 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: compact ? 6 : 8),
          if (!compact) ...[
            Text(
              'Servidor',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            _label(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
