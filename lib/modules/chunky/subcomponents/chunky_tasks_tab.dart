import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/buttons/app_button.dart';
import '../../../components/inputs/app_text_input.dart';
import '../../../components/shared/app_variant.dart';
import '../../../config/theme/app_colors.dart';
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
        AppTextInput(
          controller: _searchController,
          hint: 'Pesquisar task por nome, mundo, shape ou pattern',
          prefixIcon: const Icon(Icons.search_rounded),
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            AppButton(
              label: 'Atualizar',
              icon: Icons.refresh_rounded,
              variant: AppVariant.info,
              transparent: true,
              onPressed: () => notifier.load(),
            ),
            AppButton(
              label: '+ Adicionar task',
              icon: Icons.add_rounded,
              variant: AppVariant.primary,
              onPressed: () => _openTaskModal(context, ref),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (state.loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (filtered.isEmpty)
          const Expanded(child: Center(child: Text('Nenhuma task encontrada.')))
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              itemCount: filtered.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final task = filtered[index];
                return _TaskCard(
                  task: task,
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
    required this.onEdit,
    required this.onDelete,
  });

  final ChunkyTask task;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final statusColor = _mapStatusColor(task.status, scheme);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 7,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  task.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              AppButton(
                label: 'Editar',
                type: AppButtonType.textButton,
                variant: AppVariant.info,
                onPressed: onEdit,
              ),
              AppButton(
                label: 'Excluir',
                type: AppButtonType.textButton,
                variant: AppVariant.danger,
                onPressed: onDelete,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Configuração de pregeneration para ${chunkyWorldLabel(task.world)}.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.9),
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 8),
          _field(context, 'Região / Mundo', chunkyWorldLabel(task.world)),
          _field(
            context,
            'Centro X/Z',
            'X ${task.centerX} | Z ${task.centerZ}',
          ),
          _field(context, 'Raio', task.radius.toStringAsFixed(0)),
          _field(context, 'Shape', task.shape),
          _field(context, 'Pattern', task.pattern),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                'Status: ',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.95),
                ),
              ),
              _StatusChip(label: task.status.label, color: statusColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _field(BuildContext context, String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyMedium,
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.9),
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                fontWeight: FontWeight.w300,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.82),
              ),
            ),
          ],
        ),
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
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
            margin: const EdgeInsets.only(right: 5),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}
