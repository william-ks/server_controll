import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/badges/app_badge.dart';
import '../../../components/buttons/app_button.dart';
import '../../../components/modal/app_modal.dart';
import '../../../components/selects/app_select.dart';
import '../../../components/shared/app_variant.dart';
import '../../../models/server_lifecycle_state.dart';
import '../../maintenance/models/maintenance_mode.dart';
import '../../server/providers/server_runtime_provider.dart';
import '../../server/services/server_health_monitor.dart';
import '../models/chunky_execution_status.dart';
import '../models/chunky_task_status.dart';
import '../providers/chunky_execution_provider.dart';
import '../providers/chunky_tasks_provider.dart';

class ChunkyExecutionTab extends ConsumerWidget {
  const ChunkyExecutionTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runtime = ref.watch(serverRuntimeProvider);
    final state = ref.watch(chunkyExecutionProvider);
    final notifier = ref.read(chunkyExecutionProvider.notifier);
    final tasksState = ref.watch(chunkyTasksProvider);
    final tasksNotifier = ref.read(chunkyTasksProvider.notifier);
    final selectedTask = tasksState.selectedTask;
    final serverOnline = runtime.lifecycle == ServerLifecycleState.online;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSelect<int>(
            label: 'Select Task',
            hint: 'Select a task',
            value: selectedTask?.id,
            items: tasksState.items
                .where((item) => item.id != null)
                .map(
                  (item) => AppSelectItem<int>(
                    value: item.id!,
                    label: '${item.name} (${chunkyWorldLabel(item.world)})',
                  ),
                )
                .toList(),
            onChanged: (value) async {
              if (value == null) return;
              try {
                await tasksNotifier.selectTask(value);
              } catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      error.toString().replaceFirst('Bad state: ', ''),
                    ),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppButton(
                label: 'Start',
                icon: Icons.play_arrow_rounded,
                variant: AppVariant.success,
                isDisabled:
                    !serverOnline ||
                    selectedTask == null ||
                    state.status == ChunkyExecutionStatus.running ||
                    state.status == ChunkyExecutionStatus.paused ||
                    state.status == ChunkyExecutionStatus.cancelling,
                onPressed: () =>
                    _startTaskWithProtection(context, ref, notifier),
              ),
              AppButton(
                label: 'Pausar',
                icon: Icons.pause_rounded,
                variant: AppVariant.warning,
                isDisabled:
                    !serverOnline ||
                    state.status != ChunkyExecutionStatus.running,
                onPressed: notifier.pause,
              ),
              if (state.status == ChunkyExecutionStatus.paused)
                AppButton(
                  label: 'Continuar',
                  icon: Icons.play_arrow_rounded,
                  variant: AppVariant.info,
                  isDisabled: !serverOnline,
                  onPressed: notifier.resume,
                ),
              AppButton(
                label: 'Cancelar',
                icon: Icons.stop_circle_outlined,
                variant: AppVariant.danger,
                isDisabled:
                    !serverOnline ||
                    (state.status != ChunkyExecutionStatus.running &&
                        state.status != ChunkyExecutionStatus.paused),
                onPressed: notifier.cancel,
              ),
              AppButton(
                label: 'Refresh',
                icon: Icons.refresh_rounded,
                variant: AppVariant.secondary,
                isDisabled: !serverOnline,
                onPressed: notifier.refreshChunkProgress,
              ),
              AppButton(
                label: 'Limpar Chunky',
                icon: Icons.cleaning_services_rounded,
                variant: AppVariant.secondary,
                onPressed: notifier.clearChunkyState,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _line(context, 'Status da execução', state.status.label),
                const SizedBox(height: 6),
                _line(
                  context,
                  'Task selecionada',
                  selectedTask?.name ?? 'Nenhuma',
                ),
                const SizedBox(height: 6),
                _line(
                  context,
                  'Region / World',
                  selectedTask == null
                      ? '-'
                      : chunkyWorldLabel(selectedTask.world),
                ),
                const SizedBox(height: 6),
                _line(
                  context,
                  'Center X/Z',
                  selectedTask == null
                      ? '-'
                      : 'X ${selectedTask.centerX} | Z ${selectedTask.centerZ}',
                ),
                const SizedBox(height: 6),
                _line(
                  context,
                  'Radius',
                  selectedTask == null
                      ? '${state.currentRadius}'
                      : selectedTask.radius.toStringAsFixed(0),
                ),
                const SizedBox(height: 6),
                _line(context, 'Shape', selectedTask?.shape ?? '-'),
                const SizedBox(height: 6),
                _line(context, 'Pattern', selectedTask?.pattern ?? '-'),
                const SizedBox(height: 6),
                _line(context, 'Total Time', _formatDuration(state.elapsed)),
                const SizedBox(height: 6),
                _line(
                  context,
                  'Backup before start',
                  selectedTask == null
                      ? '-'
                      : (selectedTask.backupBeforeStart
                            ? 'Enabled'
                            : 'Disabled'),
                ),
                const SizedBox(height: 10),
                AppBadge(
                  icon: state.tasksPending
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_outline_rounded,
                  variant: state.tasksPending
                      ? AppVariant.warning
                      : AppVariant.success,
                  title: state.tasksPending
                      ? 'Arquivos de tarefa do Chunky: ENCONTRADOS'
                      : 'Arquivos de tarefa do Chunky: NAO ENCONTRADOS',
                ),
                if (state.pendingTasks.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _pendingTaskCard(context, state),
                ],
                const SizedBox(height: 8),
                _line(
                  context,
                  'Saude do servidor',
                  state.serverHealthState.label,
                ),
                const SizedBox(height: 6),
                _line(
                  context,
                  'Overloads (janela 30s)',
                  '${state.overloadEventsInWindow}',
                ),
                const SizedBox(height: 6),
                _line(
                  context,
                  'Reinicios (ultima hora)',
                  '${state.restartsInLastHour}',
                ),
                if (state.lastMsBehind != null &&
                    state.lastTicksBehind != null) ...[
                  const SizedBox(height: 6),
                  _line(
                    context,
                    'Ultimo overload',
                    '${state.lastMsBehind}ms / ${state.lastTicksBehind} ticks',
                  ),
                ],
                if (selectedTask != null) ...[
                  const SizedBox(height: 6),
                  _line(context, 'Task status', selectedTask.status.label),
                  if (selectedTask.status == ChunkyTaskStatus.running)
                    const SizedBox(height: 4),
                ],
                if (state.statusMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    state.statusMessage!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (state.healthStatusMessage != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    state.healthStatusMessage!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Progresso da execução atual',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          _buildRoundedProgressBar(
            context,
            value: (state.currentRunProgress / 100).clamp(0, 1),
          ),
          const SizedBox(height: 6),
          Text('${state.currentRunProgress.toStringAsFixed(1)}%'),
          const SizedBox(height: 12),
          Text(
            'Progresso total',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(
              begin: 0,
              end: (state.totalProgress / 100).clamp(0, 1),
            ),
            duration: const Duration(milliseconds: 350),
            builder: (context, value, _) {
              return _buildRoundedProgressBar(context, value: value);
            },
          ),
          const SizedBox(height: 6),
          Text('${state.totalProgress.toStringAsFixed(1)}%'),
          if (state.errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              state.errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _startTaskWithProtection(
    BuildContext context,
    WidgetRef ref,
    ChunkyExecutionNotifier notifier,
  ) async {
    final selection = await showDialog<_ChunkProtectionSelection>(
      context: context,
      builder: (_) => const _ChunkProtectionModal(),
    );
    if (selection == null) {
      return;
    }

    await notifier.configureChunkProtection(
      enabled: selection.enabled,
      mode: selection.mode,
    );
    await notifier.startSelectedTask();
  }

  Widget _line(BuildContext context, String label, String value) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        Expanded(child: Text(value, overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  Widget _pendingTaskCard(BuildContext context, ChunkyExecutionState state) {
    final task = state.pendingTasks.first;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Task pendente detectada',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          _line(context, 'Arquivo', task.filePath),
          const SizedBox(height: 4),
          _line(context, 'World', task.world),
          const SizedBox(height: 4),
          _line(context, 'Center X/Z', '${task.centerX} / ${task.centerZ}'),
          const SizedBox(height: 4),
          _line(context, 'Radius', '${task.radius}'),
          const SizedBox(height: 4),
          _line(context, 'Shape / Pattern', '${task.shape} / ${task.pattern}'),
          const SizedBox(height: 4),
          _line(context, 'Chunks', '${task.chunks}'),
          const SizedBox(height: 4),
          _line(context, 'Time', '${task.time}'),
          const SizedBox(height: 4),
          _line(context, 'Cancelled', task.cancelled ? 'true' : 'false'),
        ],
      ),
    );
  }

  Widget _buildRoundedProgressBar(
    BuildContext context, {
    required double value,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return LinearProgressIndicator(
      value: value,
      minHeight: 8,
      borderRadius: BorderRadius.circular(999),
      backgroundColor: scheme.onPrimary,
      valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
    );
  }

  String _formatDuration(Duration duration) {
    final hh = duration.inHours.toString().padLeft(2, '0');
    final mm = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final ss = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }
}

class _ChunkProtectionSelection {
  const _ChunkProtectionSelection({required this.enabled, this.mode});

  final bool enabled;
  final MaintenanceMode? mode;
}

class _ChunkProtectionModal extends StatefulWidget {
  const _ChunkProtectionModal();

  @override
  State<_ChunkProtectionModal> createState() => _ChunkProtectionModalState();
}

class _ChunkProtectionModalState extends State<_ChunkProtectionModal> {
  bool _enabled = false;
  MaintenanceMode _mode = MaintenanceMode.total;

  @override
  Widget build(BuildContext context) {
    return AppModal(
      icon: Icons.security_rounded,
      title: 'Proteção durante geração',
      width: 560,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Deseja ativar proteção de entrada enquanto o Chunky estiver em execução?',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: _enabled,
            contentPadding: EdgeInsets.zero,
            title: const Text('Ativar proteção'),
            subtitle: const Text(
              'Reaproveita o mesmo mecanismo do modo de manutenção.',
            ),
            onChanged: (value) => setState(() => _enabled = value),
          ),
          const SizedBox(height: 8),
          AppSelect<MaintenanceMode>(
            label: 'Tipo de proteção',
            value: _mode,
            items: const [
              AppSelectItem(
                value: MaintenanceMode.total,
                label: 'Bloquear todos',
              ),
              AppSelectItem(
                value: MaintenanceMode.adminsOnly,
                label: 'Permitir apenas admins do app',
              ),
            ],
            onChanged: _enabled
                ? (value) {
                    if (value == null) return;
                    setState(() => _mode = value);
                  }
                : null,
          ),
        ],
      ),
      actions: [
        AppButton(
          label: 'Cancelar',
          onPressed: () => Navigator.of(context).pop(),
          type: AppButtonType.textButton,
          variant: AppVariant.danger,
        ),
        AppButton(
          label: 'Iniciar geração',
          onPressed: () {
            Navigator.of(context).pop(
              _ChunkProtectionSelection(
                enabled: _enabled,
                mode: _enabled ? _mode : null,
              ),
            );
          },
          variant: AppVariant.success,
          icon: Icons.play_arrow_rounded,
        ),
      ],
    );
  }
}
