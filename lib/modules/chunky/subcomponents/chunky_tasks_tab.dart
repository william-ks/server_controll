import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/buttons/app_button.dart';
import '../../../components/inputs/app_text_input.dart';
import '../../../components/shared/app_variant.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_theme_extension.dart';
import '../models/chunky_task.dart';
import '../models/chunky_task_status.dart';
import '../providers/chunky_tasks_provider.dart';
import 'add_edit_chunky_task_modal.dart';

class ChunkyTasksTab extends ConsumerStatefulWidget {
  const ChunkyTasksTab({super.key});

  @override
  ConsumerState<ChunkyTasksTab> createState() => _ChunkyTasksTabState();        
}

class _ChunkyTasksTabState extends ConsumerState<ChunkyTasksTab> {
  final TextEditingController _searchController = TextEditingController();      
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chunkyTasksProvider);
    final notifier = ref.read(chunkyTasksProvider.notifier);
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    final filtered = state.items.where((task) {
      if (_query.trim().isEmpty) return true;
      final q = _query.toLowerCase();
      return task.name.toLowerCase().contains(q) ||
          chunkyWorldLabel(task.world).toLowerCase().contains(q) ||
          task.shape.toLowerCase().contains(q) ||
          task.pattern.toLowerCase().contains(q);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: AppTextInput(
                controller: _searchController,
                hint: 'Pesquisar task por nome, mundo, shape ou pattern',
                prefixIcon: const Icon(Icons.search_rounded),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            const SizedBox(width: 16),
            AppButton(
              label: 'Atualizar',
              icon: Icons.refresh_rounded,
              variant: AppVariant.info,
              transparent: true,
              onPressed: () => notifier.load(),
            ),
            const SizedBox(width: 8),
            AppButton(
              label: 'Nova Task',
              icon: Icons.add_rounded,
              variant: AppVariant.primary,
              onPressed: () => _openTaskModal(context, ref),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (state.loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))     
        else if (filtered.isEmpty)
          const Expanded(child: Center(child: Text('Nenhuma task encontrada.')))
        else
          Expanded(
            child: ListView.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final task = filtered[index];
                return _TaskCard(
                  task: task,
                  ext: ext,
                  onEdit: () => _openTaskModal(context, ref, task: task),       
                  onDelete: () async {
                    final id = task.id;
                    if (id == null) return;
                    await notifier.deleteTask(id);
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  Future<void> _openTaskModal(
    BuildContext context,
    WidgetRef ref, {
    ChunkyTask? task,
  }) async {
    final notifier = ref.read(chunkyTasksProvider.notifier);
    await showDialog<void>(
      context: context,
      builder: (_) => AddEditChunkyTaskModal(
        initialTask: task,
        onCreate:
            ({
              required String name,
              required String world,
              required int centerX,
              required int centerZ,
              required double radius,
              required String shape,
              required String pattern,
              required bool maintenanceEnabled,
              String? maintenanceMode,
            }) {
              return notifier.create(
                name: name,
                world: world,
                centerX: centerX,
                centerZ: centerZ,
                radius: radius,
                shape: shape,
                pattern: pattern,
                maintenanceEnabled: maintenanceEnabled,
                maintenanceMode: maintenanceMode,
              );
            },
        onUpdate: notifier.updateTask,
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.ext,
    required this.onEdit,
    required this.onDelete,
  });

  final ChunkyTask task;
  final AppThemeExtension ext;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final statusColor = _mapStatusColor(task.status, scheme);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ext.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ext.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      task.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(     
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _StatusChip(label: task.status.label, color: statusColor),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Pré-geração em lote.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 24,
                  runSpacing: 12,
                  children: [
                    _field(context, 'Mundo', chunkyWorldLabel(task.world)),      
                    _field(context, 'Centro', 'X: ${task.centerX} | Z: ${task.centerZ}'),
                    _field(context, 'Raio', task.radius.toStringAsFixed(0)),
                    _field(context, 'Formato', task.shape),
                    _field(context, 'Padrão', task.pattern),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            children: [
              AppButton(
                label: 'Editar',
                icon: Icons.edit_rounded,
                variant: AppVariant.info,
                type: AppButtonType.textButton,
                onPressed: onEdit,
              ),
              const SizedBox(height: 8),
              AppButton(
                label: 'Excluir',
                icon: Icons.delete_outline_rounded,
                variant: AppVariant.danger,
                type: AppButtonType.textButton,
                onPressed: onDelete,
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _field(BuildContext context, String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
              ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }

  Color _mapStatusColor(ChunkyTaskStatus status, ColorScheme scheme) {
    return switch (status) {
      ChunkyTaskStatus.draft => scheme.onSurfaceVariant.withValues(alpha: 0.86),
      ChunkyTaskStatus.selected => AppColors.primary,
      ChunkyTaskStatus.running => AppColors.success,
      ChunkyTaskStatus.paused => AppColors.warning,
      ChunkyTaskStatus.completed => AppColors.success,
      ChunkyTaskStatus.cancelled => AppColors.danger,
    };
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),    
          ),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
