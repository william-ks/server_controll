import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_theme_extension.dart';
import '../../../../models/server_lifecycle_state.dart';

class StatusCard extends StatelessWidget {
  const StatusCard({super.key, required this.lifecycle});

  final ServerLifecycleState lifecycle;

  @override
  Widget build(BuildContext context) {
    final isOnline = lifecycle == ServerLifecycleState.online;
    return _MetricCard(
      title: 'Status',
      value: isOnline ? 'online' : lifecycle.name,
      icon: Icons.offline_bolt_rounded,
      valueColor: isOnline ? AppColors.primary : AppColors.neutral,
    );
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
