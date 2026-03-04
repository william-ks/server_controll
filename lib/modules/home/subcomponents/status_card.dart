import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_theme_extension.dart';
import '../../../../models/server_lifecycle_state.dart';

class StatusCard extends StatelessWidget {
  const StatusCard({super.key, required this.lifecycle});

  final ServerLifecycleState lifecycle;

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
    final isOnline = lifecycle == ServerLifecycleState.online;
    return _MetricCard(
      title: 'STATUS',
      value: _label(lifecycle).toUpperCase(),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: valueColor)),
        ],
      ),
    );
  }
}
