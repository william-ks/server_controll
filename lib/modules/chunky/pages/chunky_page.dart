import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/routes/routes_config.dart';
import '../../../config/theme/app_styles.dart';
import '../../../layout/default_layout.dart';
import '../models/chunky_tab.dart';
import '../providers/chunky_tab_provider.dart';
import '../subcomponents/chunky_execution_tab.dart';
import '../subcomponents/chunky_logs_tab.dart';
import '../subcomponents/chunky_tasks_tab.dart';

class ChunkyPage extends ConsumerStatefulWidget {
  const ChunkyPage({super.key});

  @override
  ConsumerState<ChunkyPage> createState() => _ChunkyPageState();
}

class _ChunkyPageState extends ConsumerState<ChunkyPage> {
  void _setTab(ChunkyTab tab) {
    ref.read(chunkyTabProvider.notifier).setTab(tab);
  }

  @override
  Widget build(BuildContext context) {
    final activeTab = ref.watch(chunkyTabProvider);

    return DefaultLayout(
      title: 'Chunky',
      currentRoute: AppRoutes.chunky,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ChunkyTabChip(
                  label: 'Execução',
                  active: activeTab == ChunkyTab.execution,
                  onTap: () => _setTab(ChunkyTab.execution),
                ),
                _ChunkyTabChip(
                  label: 'Tasks',
                  active: activeTab == ChunkyTab.tasks,
                  onTap: () => _setTab(ChunkyTab.tasks),
                ),
                _ChunkyTabChip(
                  label: 'Logs',
                  active: activeTab == ChunkyTab.logs,
                  onTap: () => _setTab(ChunkyTab.logs),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: switch (activeTab) {
                ChunkyTab.execution => const ChunkyExecutionTab(),
                ChunkyTab.tasks => const ChunkyTasksTab(),
                ChunkyTab.logs => const ChunkyLogsTab(),
              },
            ),
          ],
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
