import 'package:flutter/material.dart';

import '../../../../models/server_lifecycle_state.dart';
import '../../../../theme/app_colors.dart';

class StatusCard extends StatelessWidget {
  const StatusCard({super.key, required this.lifecycle});

  final ServerLifecycleState lifecycle;

  @override
  Widget build(BuildContext context) {
    final isOnline = lifecycle == ServerLifecycleState.online;
    return _MetricCard(
      title: 'Status',
      value: lifecycle.name,
      color: isOnline ? AppColors.primary : AppColors.neutral,
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.title, required this.value, required this.color});

  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color)),
        ],
      ),
    );
  }
}
