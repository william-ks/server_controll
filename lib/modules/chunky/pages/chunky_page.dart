import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/routes/routes_config.dart';
import '../../../config/theme/app_styles.dart';
import '../../../layout/default_layout.dart';
import '../models/chunky_tab.dart';
import '../providers/chunky_tab_provider.dart';

class ChunkyPage extends ConsumerWidget {
  const ChunkyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTab = ref.watch(chunkyTabProvider);
    final tabNotifier = ref.read(chunkyTabProvider.notifier);

    return DefaultLayout(
      title: 'MineControl',
      currentRoute: AppRoutes.chunky,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: AppStyles.radiusLg,
            border: Border.all(color: Theme.of(context).dividerColor),
            boxShadow: AppStyles.softShadow(opacity: 0.18),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Align(
                alignment: Alignment.center,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ChunkyTabChip(
                      label: 'Execução',
                      active: activeTab == ChunkyTab.execution,
                      onTap: () => tabNotifier.setTab(ChunkyTab.execution),
                    ),
                    _ChunkyTabChip(
                      label: 'Config',
                      active: activeTab == ChunkyTab.config,
                      onTap: () => tabNotifier.setTab(ChunkyTab.config),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: switch (activeTab) {
                  ChunkyTab.execution => const _ChunkyExecutionPlaceholder(),
                  ChunkyTab.config => const _ChunkyConfigPlaceholder(),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChunkyTabChip extends StatelessWidget {
  const _ChunkyTabChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: AppStyles.radiusFull,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: AppStyles.radiusFull,
          border: Border.all(
            color: active ? scheme.primary : Theme.of(context).dividerColor,
          ),
          color: active
              ? scheme.primary.withValues(alpha: 0.14)
              : Colors.transparent,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? scheme.primary : scheme.onSurface,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _ChunkyExecutionPlaceholder extends StatelessWidget {
  const _ChunkyExecutionPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.topLeft,
      child: Text('Execução em construção.'),
    );
  }
}

class _ChunkyConfigPlaceholder extends StatelessWidget {
  const _ChunkyConfigPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.topLeft,
      child: Text('Config em construção.'),
    );
  }
}
