import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_theme_extension.dart';
import '../../../../models/server_lifecycle_state.dart';

class StatusCard extends StatelessWidget {
  const StatusCard({super.key, required this.lifecycle});

  final ServerLifecycleState lifecycle;

  Color _valueColor() {
    return switch (lifecycle) {
      ServerLifecycleState.offline => AppColors.neutral,
      ServerLifecycleState.starting => AppColors.primary,
      ServerLifecycleState.online => AppColors.success,
      ServerLifecycleState.stopping => AppColors.danger,
      ServerLifecycleState.restarting => AppColors.primary,
      ServerLifecycleState.error => AppColors.danger,
    };
  }

  String _label(ServerLifecycleState state) {
    return switch (state) {
      ServerLifecycleState.offline => 'OFFLINE',
      ServerLifecycleState.starting => 'STARTING',
      ServerLifecycleState.online => 'ONLINE',
      ServerLifecycleState.stopping => 'SHUTTING DOWN',
      ServerLifecycleState.restarting => 'STARTING',
      ServerLifecycleState.error => 'OFFLINE',
    };
  }

  @override
  Widget build(BuildContext context) {
    return _MetricCard(
      title: 'STATUS',
      value: _label(lifecycle).toUpperCase(),
      icon: Icons.offline_bolt_rounded,
      valueColor: _valueColor(),
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: valueColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: valueColor.withValues(alpha: 0.5),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: valueColor,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
