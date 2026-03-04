import 'package:flutter/material.dart';

import '../../../../models/server_lifecycle_state.dart';
import '../../../../theme/app_colors.dart';

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
      color: active ? AppColors.primary : AppColors.neutral,
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
