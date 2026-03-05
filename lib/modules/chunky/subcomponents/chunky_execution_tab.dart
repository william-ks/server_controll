import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/badges/app_badge.dart';
import '../../../components/buttons/app_button.dart';
import '../../../components/inputs/app_switch_card.dart';
import '../../../components/shared/app_variant.dart';
import '../../../models/server_lifecycle_state.dart';
import '../../server/providers/server_runtime_provider.dart';
import '../models/chunky_execution_status.dart';
import '../providers/chunky_execution_provider.dart';

class ChunkyExecutionTab extends ConsumerWidget {
  const ChunkyExecutionTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runtime = ref.watch(serverRuntimeProvider);
    final state = ref.watch(chunkyExecutionProvider);
    final notifier = ref.read(chunkyExecutionProvider.notifier);
    final serverOnline = runtime.lifecycle == ServerLifecycleState.online;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppButton(
                label: 'Reiniciar do zero',
                icon: Icons.play_arrow_rounded,
                variant: AppVariant.success,
                isDisabled:
                    !serverOnline ||
                    state.status == ChunkyExecutionStatus.running ||
                    state.status == ChunkyExecutionStatus.paused ||
                    state.status == ChunkyExecutionStatus.cancelling,
                onPressed: () async {
                  if (runtime.activePlayers > 0) {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Jogadores online'),
                        content: const Text(
                          'Existem jogadores online. Deseja reiniciar e desligar o servidor agora?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancelar'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Confirmar'),
                          ),
                        ],
                      ),
                    );
                    if (confirm != true) return;
                  }
                  await notifier.restartExecutionFromZero();
                },
              ),
              if (state.hasRecoverableCheckpoint ||
                  state.status == ChunkyExecutionStatus.awaitingResume)
                AppButton(
                  label: 'Continuar tarefa',
                  icon: Icons.play_circle_fill_rounded,
                  variant: AppVariant.info,
                  isDisabled:
                      !serverOnline ||
                      state.status == ChunkyExecutionStatus.running ||
                      state.status == ChunkyExecutionStatus.cancelling,
                  onPressed: notifier.continueExecution,
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
                  'Execução atual',
                  state.totalRuns == 0
                      ? 'Execução 0 de 0'
                      : 'Execução ${state.currentRun} de ${state.totalRuns}',
                ),
                const SizedBox(height: 6),
                _line(context, 'Radius atual', '${state.currentRadius}'),
                const SizedBox(height: 6),
                _line(context, 'Total de execuções', '${state.totalRuns}'),
                const SizedBox(height: 6),
                _line(context, 'Elapsed time', _formatDuration(state.elapsed)),
                const SizedBox(height: 10),
                AppSwitchCard(
                  label: 'Efetuar backup antes de iniciar',
                  value: state.backupBeforeStart,
                  onChanged: notifier.setBackupBeforeStart,
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
                if (state.statusMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    state.statusMessage!,
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
            'Progresso total do plano',
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
