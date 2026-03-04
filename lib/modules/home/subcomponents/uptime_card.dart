import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_theme_extension.dart';
import '../../../../models/server_lifecycle_state.dart';

class UptimeCard extends StatelessWidget {
  const UptimeCard({super.key, required this.uptime, required this.lifecycle});

  final Duration uptime;
  final ServerLifecycleState lifecycle;

  @override
  Widget build(BuildContext context) {
    final active = lifecycle == ServerLifecycleState.online;
    return _MetricCard(
      title: 'Uptime',
      value: _formatDuration(uptime),
      icon: Icons.timer_outlined,
      valueColor: active ? AppColors.primary : AppColors.neutral,
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.valueColor,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
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
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 6),
                Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: valueColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
