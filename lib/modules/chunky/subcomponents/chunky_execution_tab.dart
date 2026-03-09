import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/badges/app_badge.dart';
import '../../../components/buttons/app_button.dart';
import '../../../components/modal/app_confirm_dialog.dart';
import '../../../components/selects/app_select.dart';
import '../../../components/shared/app_variant.dart';
import '../../../config/theme/app_theme_extension.dart';
import '../../../models/server_lifecycle_state.dart';
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
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AppSelect<int>(
                  label: 'Selecionar Task',
                  hint: 'Selecione a task para execução',
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
              ),
            ],
          ),
          const SizedBox(height: 16),
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
                onPressed: () => _confirmAndStartTask(context, notifier),       
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
                label: 'Atualizar',
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
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: ext.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ext.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estado Geral',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                _infoRow(context, 'Status Chunky', state.status.label),
                _infoRow(context, 'Saúde do Servidor', state.serverHealthState.label),
                _infoRow(context, 'Total Processado', '${state.totalProgress.toStringAsFixed(1)}%'),
                _infoRow(context, 'Tempo Decorrido', _formatDuration(state.elapsed)),
                if (state.statusMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    state.statusMessage!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                  ),
                ],
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                      begin: 0,
                      end: (state.totalProgress / 100).clamp(0, 1),
                    ),
                    duration: const Duration(milliseconds: 350),
                    builder: (context, value, _) {
                      return LinearProgressIndicator(
                        value: value,
                        minHeight: 12,
                        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                        valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: ext.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: ext.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Detalhes da Task',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 16),
                      if (selectedTask != null) ...[
                        _infoRow(context, 'Nome', selectedTask.name),
                        _infoRow(context, 'Região', chunkyWorldLabel(selectedTask.world)),
                        _infoRow(context, 'Centro', 'X: ${selectedTask.centerX} | Z: ${selectedTask.centerZ}'),
                        _infoRow(context, 'Raio', '${selectedTask.radius.toStringAsFixed(0)} blocos'),
                        _infoRow(context, 'Formato', selectedTask.shape),
                        _infoRow(context, 'Padrão', selectedTask.pattern),
                      ] else ...[
                        const Text('Nenhuma task selecionada.'),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: ext.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: ext.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Performance',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 16),
                      _infoRow(context, 'Overloads (30s)', '${state.overloadEventsInWindow}'),
                      _infoRow(context, 'Reinícios (1h)', '${state.restartsInLastHour}'),
                      if (state.lastMsBehind != null && state.lastTicksBehind != null)
                        _infoRow(context, 'Último Lag', '${state.lastMsBehind}ms (${state.lastTicksBehind} tks)'),
                      const SizedBox(height: 12),
                      AppBadge(
                        icon: state.tasksPending
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle_outline_rounded,
                        variant: state.tasksPending
                            ? AppVariant.warning
                            : AppVariant.success,
                        title: state.tasksPending
                            ? 'Pendências detectadas'
                            : 'Limpo',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (state.pendingTasks.isNotEmpty) ...[
             const SizedBox(height: 16),
             _pendingTaskCard(context, state, ext),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmAndStartTask(
    BuildContext context,
    ChunkyExecutionNotifier notifier,
  ) async {
    final confirmed = await showAppConfirmDialog(
      context,
      icon: Icons.play_arrow_rounded,
      title: 'Iniciar task selecionada?',
      message:
          'A task será iniciada com as configurações já salvas nela, incluindo manutenção quando habilitada.',
      confirmLabel: 'Iniciar',
      cancelLabel: 'Cancelar',
      confirmVariant: AppVariant.success,
      cancelVariant: AppVariant.danger,
      confirmIcon: Icons.play_arrow_rounded,
    );
    if (!confirmed) {
      return;
    }

    await notifier.startSelectedTask();
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pendingTaskCard(BuildContext context, ChunkyExecutionState state, AppThemeExtension ext) {   
    final task = state.pendingTasks.first;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.error.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.report_problem_rounded, color: Theme.of(context).colorScheme.error),
              const SizedBox(width: 8),
              Text(
                'Task Inacabada Detectada',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.error,
                    ),      
              ),
            ],
          ),
          const SizedBox(height: 12),
          _infoRow(context, 'Arquivo / Mundo', '${task.filePath} / ${task.world}'),
          _infoRow(context, 'Posição', 'X ${task.centerX} Z ${task.centerZ}, r=${task.radius}'),
          _infoRow(context, 'Progresso', '${task.chunks} chunks (${task.time})'),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hh = duration.inHours.toString().padLeft(2, '0');
    final mm = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final ss = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }
}
