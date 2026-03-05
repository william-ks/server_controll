import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/routes/routes_config.dart';
import '../../../config/theme/app_styles.dart';
import '../../../layout/default_layout.dart';
import '../models/chunky_tab.dart';
import '../providers/chunky_tab_provider.dart';
import '../subcomponents/chunky_config_tab.dart';
import '../subcomponents/chunky_execution_tab.dart';

class ChunkyPage extends ConsumerStatefulWidget {
  const ChunkyPage({super.key});

  @override
  ConsumerState<ChunkyPage> createState() => _ChunkyPageState();
}

class _ChunkyPageState extends ConsumerState<ChunkyPage> {
  int _configReloadToken = 0;

  void _setTab(ChunkyTab tab) {
    final current = ref.read(chunkyTabProvider);
    if (current != tab && tab == ChunkyTab.config) {
      setState(() => _configReloadToken++);
    }
    ref.read(chunkyTabProvider.notifier).setTab(tab);
  }

  @override
  Widget build(BuildContext context) {
    final activeTab = ref.watch(chunkyTabProvider);

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
                      onTap: () => _setTab(ChunkyTab.execution),
                    ),
                    _ChunkyTabChip(
                      label: 'Config',
                      active: activeTab == ChunkyTab.config,
                      onTap: () => _setTab(ChunkyTab.config),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: switch (activeTab) {
                  ChunkyTab.execution => const ChunkyExecutionTab(),
                  ChunkyTab.config => ChunkyConfigTab(
                    key: ValueKey('chunky-config-$_configReloadToken'),
                  ),
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
