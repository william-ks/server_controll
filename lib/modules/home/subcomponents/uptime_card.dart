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
      title: 'UPTIME',
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Icon(icon, color: ext.mutedText, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: ext.mutedText,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        const Spacer(),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: valueColor,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}
