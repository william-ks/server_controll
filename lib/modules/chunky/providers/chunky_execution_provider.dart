import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../database/app_database.dart';
import '../../../models/server_lifecycle_state.dart';
import '../../backup/providers/backup_config_provider.dart';
import '../../backup/providers/backups_provider.dart';
import '../../backup/services/backup_service.dart';
import '../../config/providers/config_files_provider.dart';
import '../../config/services/server_properties_service.dart';
import '../../server/providers/server_runtime_provider.dart';
import '../../server/services/server_process_service.dart';
import '../models/chunky_config_settings.dart';
import '../models/chunky_execution_log_entry.dart';
import '../models/chunky_execution_status.dart';
import '../providers/chunky_config_provider.dart';

class ChunkyExecutionState {
  const ChunkyExecutionState({
    required this.status,
    required this.currentRun,
    required this.currentRadius,
    required this.totalRuns,
    required this.currentRunProgress,
    required this.totalProgress,
    required this.elapsed,
    required this.plan,
    required this.tasksPending,
    required this.backupBeforeStart,
    required this.hasRecoverableCheckpoint,
    required this.logs,
    this.errorMessage,
    this.statusMessage,
  });

  final ChunkyExecutionStatus status;
  final int currentRun;
  final int currentRadius;
  final int totalRuns;
  final double currentRunProgress;
  final double totalProgress;
  final Duration elapsed;
  final List<int> plan;
  final bool tasksPending;
  final bool backupBeforeStart;
  final bool hasRecoverableCheckpoint;
  final List<ChunkyExecutionLogEntry> logs;
  final String? errorMessage;
  final String? statusMessage;

  ChunkyExecutionState copyWith({
    ChunkyExecutionStatus? status,
    int? currentRun,
    int? currentRadius,
    int? totalRuns,
    double? currentRunProgress,
    double? totalProgress,
    Duration? elapsed,
    List<int>? plan,
    bool? tasksPending,
    bool? backupBeforeStart,
    bool? hasRecoverableCheckpoint,
    List<ChunkyExecutionLogEntry>? logs,
    String? errorMessage,
    String? statusMessage,
    bool clearError = false,
    bool clearStatusMessage = false,
  }) {
    return ChunkyExecutionState(
      status: status ?? this.status,
      currentRun: currentRun ?? this.currentRun,
      currentRadius: currentRadius ?? this.currentRadius,
      totalRuns: totalRuns ?? this.totalRuns,
      currentRunProgress: currentRunProgress ?? this.currentRunProgress,
      totalProgress: totalProgress ?? this.totalProgress,
      elapsed: elapsed ?? this.elapsed,
      plan: plan ?? this.plan,
      tasksPending: tasksPending ?? this.tasksPending,
      backupBeforeStart: backupBeforeStart ?? this.backupBeforeStart,
      hasRecoverableCheckpoint:
          hasRecoverableCheckpoint ?? this.hasRecoverableCheckpoint,
      logs: logs ?? this.logs,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      statusMessage: clearStatusMessage
          ? null
          : (statusMessage ?? this.statusMessage),
    );
  }

  factory ChunkyExecutionState.initial() {
    return const ChunkyExecutionState(
      status: ChunkyExecutionStatus.idle,
      currentRun: 0,
      currentRadius: 0,
      totalRuns: 0,
      currentRunProgress: 0,
      totalProgress: 0,
      elapsed: Duration.zero,
      plan: [],
      tasksPending: false,
      backupBeforeStart: false,
      hasRecoverableCheckpoint: false,
      logs: [],
    );
  }
}

final chunkyExecutionProvider =
    NotifierProvider<ChunkyExecutionNotifier, ChunkyExecutionState>(
      ChunkyExecutionNotifier.new,
    );

class ChunkyExecutionNotifier extends Notifier<ChunkyExecutionState> {
  static const int _gcPauseSeconds = 20;
  static const int _saveAllAckTimeoutSeconds = 20;
  static const int _memoryObserveSeconds = 60;
  static const int _memoryObserveStepSeconds = 5;
  static const int _memoryStableThresholdMb = 5 * 1024;

  final ServerPropertiesService _propertiesService = ServerPropertiesService();
  StreamSubscription<String>? _stdoutSub;
  Timer? _elapsedTimer;
  Completer<void>? _runCompleter;
  Completer<bool>? _saveAllCompleter;
  bool _cancelRequested = false;
  bool _paused = false;
  bool _pauseAfterCurrentCycleRequested = false;
  bool _resumeOnNextOnline = false;
  int _completedRuns = 0;
  Duration _runElapsedStart = Duration.zero;

  @override
  ChunkyExecutionState build() {
    _stdoutSub = ref
        .read(serverProcessServiceProvider)
        .stdoutLines
        .listen(_handleStdoutLine);
    Future<void>(() => _bootstrap());
    ref.listen(serverRuntimeProvider, (previous, next) {
      if (!_resumeOnNextOnline) return;
      if (next.lifecycle != ServerLifecycleState.online) return;
      if (state.status != ChunkyExecutionStatus.paused) return;
      _resumeOnNextOnline = false;
      unawaited(resumeAfterScheduleIfOnline());
    });

    ref.onDispose(() {
      _elapsedTimer?.cancel();
      unawaited(_stdoutSub?.cancel());
    });

    return ChunkyExecutionState.initial();
  }

  Future<void> _bootstrap() async {
    final backupBeforeStart = ref.read(chunkyConfigProvider).backupBeforeStart;
    await refreshTasksPending();
    await _loadLogsFromDb();

    final checkpoint = await _loadCheckpoint();
    if (checkpoint != null && checkpoint.plan.isNotEmpty) {
      final currentRun = checkpoint.currentRun.clamp(1, checkpoint.plan.length);
      final currentRadius = checkpoint.currentRadius == 0
          ? checkpoint.plan[currentRun - 1]
          : checkpoint.currentRadius;

      state = state.copyWith(
        backupBeforeStart: backupBeforeStart,
        status: ChunkyExecutionStatus.awaitingResume,
        currentRun: currentRun,
        currentRadius: currentRadius,
        totalRuns: checkpoint.totalRuns,
        currentRunProgress: checkpoint.currentRunProgress,
        totalProgress: checkpoint.totalProgress,
        elapsed: Duration(seconds: checkpoint.elapsedSeconds),
        plan: checkpoint.plan,
        hasRecoverableCheckpoint: true,
        statusMessage: state.tasksPending
            ? 'Execução anterior detectada. Existem tarefas do Chunky pendentes em disco.'
            : 'Execução anterior detectada. Sem arquivos pendentes; ao continuar, a execução atual será recriada.',
      );
      await _appendLog(
        'Checkpoint carregado: execução $currentRun/${checkpoint.totalRuns}, radius $currentRadius.',
      );
      return;
    }

    state = state.copyWith(backupBeforeStart: backupBeforeStart);
  }

  Future<void> refreshTasksPending() async {
    final serverPath = ref.read(configFilesProvider).serverPath.trim();
    final pending = await _hasPendingTasks(serverPath);
    state = state.copyWith(tasksPending: pending);
  }

  Future<void> setBackupBeforeStart(bool enabled) async {
    final settings = ref.read(chunkyConfigProvider);
    final next = ChunkyConfigSettings(
      centerX: settings.centerX,
      centerZ: settings.centerZ,
      radius: settings.radius,
      pattern: settings.pattern,
      shape: settings.shape,
      maxChunksPerRun: settings.maxChunksPerRun,
      backupBeforeStart: enabled,
      radiusMode: settings.radiusMode,
    );
    await ref.read(chunkyConfigProvider.notifier).save(next);
    state = state.copyWith(backupBeforeStart: enabled);
    await _appendLog(
      'Backup antes de iniciar: ${enabled ? 'ATIVO' : 'DESATIVADO'}.',
    );
  }

  String buildLogsAsPlainText() {
    final buffer = StringBuffer();
    for (final entry in state.logs) {
      final hh = entry.timestamp.hour.toString().padLeft(2, '0');
      final mm = entry.timestamp.minute.toString().padLeft(2, '0');
      final ss = entry.timestamp.second.toString().padLeft(2, '0');
      final runLabel = entry.totalRuns > 0
          ? ' run ${entry.runIndex}/${entry.totalRuns}'
          : '';
      final radiusLabel = entry.radius > 0 ? ' radius ${entry.radius}' : '';
      final elapsedLabel = _formatDuration(entry.elapsed);
      buffer.writeln(
        '[$hh:$mm:$ss] [${entry.level}] [elapsed $elapsedLabel]$runLabel$radiusLabel ${entry.message}',
      );
    }
    return buffer.toString();
  }

  List<int> buildRunPlan({required int radius, required int maxPerRun}) {
    if (radius <= 0 || maxPerRun <= 0) return [];
    final plan = <int>[];
    var current = maxPerRun;
    while (current < radius) {
      plan.add(current);
      current += maxPerRun;
    }
    plan.add(radius);
    return plan;
  }

  Future<void> startExecution() async {
    await restartExecutionFromZero();
  }

  Future<void> restartExecutionFromZero() async {
    if (state.status == ChunkyExecutionStatus.running ||
        state.status == ChunkyExecutionStatus.paused ||
        state.status == ChunkyExecutionStatus.cancelling) {
      return;
    }

    final runtime = ref.read(serverRuntimeProvider);
    if (runtime.lifecycle != ServerLifecycleState.online) {
      state = state.copyWith(
        status: ChunkyExecutionStatus.error,
        errorMessage: 'Servidor precisa estar online para iniciar o Chunky.',
      );
      await _appendLog(
        'Falha ao iniciar execução: servidor não está online.',
        level: 'ERROR',
      );
      return;
    }

    final config = ref.read(chunkyConfigProvider);
    final radius = int.tryParse(config.radius.trim()) ?? 0;
    final maxPerRun = int.tryParse(config.maxChunksPerRun.trim()) ?? 1000;
    final plan = buildRunPlan(radius: radius, maxPerRun: maxPerRun);
    if (plan.isEmpty) {
      state = state.copyWith(
        status: ChunkyExecutionStatus.error,
        errorMessage: 'Plano de execução inválido.',
      );
      await _appendLog('Plano de execução inválido.', level: 'ERROR');
      return;
    }

    _cancelRequested = false;
    _paused = false;
    _pauseAfterCurrentCycleRequested = false;
    _resumeOnNextOnline = false;
    _completedRuns = 0;
    state = state.copyWith(
      status: ChunkyExecutionStatus.running,
      currentRun: 1,
      currentRadius: plan.first,
      totalRuns: plan.length,
      plan: plan,
      currentRunProgress: 0,
      totalProgress: 0,
      elapsed: Duration.zero,
      hasRecoverableCheckpoint: false,
      clearError: true,
      clearStatusMessage: true,
    );
    _startElapsedTimer();
    await _persistCheckpoint();
    await _appendLog(
      'Execução iniciada. Plano: ${plan.length} execuções, radius final $radius.',
    );

    Future<void>(
      () => _runExecutionLoop(
        config: config,
        plan: plan,
        startIndex: 0,
        freshStart: true,
      ),
    );
  }

  Future<void> continueExecution() async {
    if (state.status == ChunkyExecutionStatus.running ||
        state.status == ChunkyExecutionStatus.cancelling) {
      return;
    }

    final runtime = ref.read(serverRuntimeProvider);
    if (runtime.lifecycle != ServerLifecycleState.online) {
      state = state.copyWith(
        status: ChunkyExecutionStatus.error,
        errorMessage: 'Servidor precisa estar online para continuar o Chunky.',
      );
      await _appendLog(
        'Falha ao continuar execução: servidor não está online.',
        level: 'ERROR',
      );
      return;
    }

    final config = ref.read(chunkyConfigProvider);
    final plan = state.plan.isNotEmpty
        ? state.plan
        : buildRunPlan(
            radius: int.tryParse(config.radius.trim()) ?? 0,
            maxPerRun: int.tryParse(config.maxChunksPerRun.trim()) ?? 1000,
          );
    if (plan.isEmpty) {
      state = state.copyWith(
        status: ChunkyExecutionStatus.error,
        errorMessage: 'Sem plano recuperável para continuar.',
      );
      await _appendLog('Sem plano recuperável para continuar.', level: 'ERROR');
      return;
    }

    final currentRun = state.currentRun <= 0 ? 1 : state.currentRun;
    final startIndex = (currentRun - 1).clamp(0, plan.length - 1);

    _cancelRequested = false;
    _paused = false;
    _pauseAfterCurrentCycleRequested = false;
    _resumeOnNextOnline = false;
    _completedRuns = startIndex;
    state = state.copyWith(
      status: ChunkyExecutionStatus.running,
      currentRun: startIndex + 1,
      currentRadius: plan[startIndex],
      totalRuns: plan.length,
      plan: plan,
      hasRecoverableCheckpoint: true,
      clearError: true,
      clearStatusMessage: true,
    );
    _startElapsedTimer();
    await _persistCheckpoint();
    await _appendLog(
      'Continuando execução em ${startIndex + 1}/${plan.length}, radius ${plan[startIndex]}.',
    );

    Future<void>(
      () => _runExecutionLoop(
        config: config,
        plan: plan,
        startIndex: startIndex,
        freshStart: false,
      ),
    );
  }

  Future<void> refreshChunkProgress() async {
    final lifecycle = ref.read(serverRuntimeProvider).lifecycle;
    if (lifecycle != ServerLifecycleState.online) return;
    await ref
        .read(serverRuntimeProvider.notifier)
        .sendCommand('chunky progress');
    await _appendLog('Solicitado chunky progress no servidor.');
  }

  Future<void> clearChunkyState() async {
    final runtimeNotifier = ref.read(serverRuntimeProvider.notifier);
    final serverPath = ref.read(configFilesProvider).serverPath.trim();
    _cancelRequested = true;
    _paused = false;
    _runCompleter?.complete();
    _runCompleter = null;
    try {
      if (ref.read(serverRuntimeProvider).lifecycle ==
          ServerLifecycleState.online) {
        await runtimeNotifier.sendCommand('chunky cancel');
      }
    } catch (_) {}
    await _clearTasksDirs(serverPath);
    await _clearCheckpoint();
    await _clearLogs();
    _elapsedTimer?.cancel();
    _completedRuns = 0;
    _pauseAfterCurrentCycleRequested = false;
    _resumeOnNextOnline = false;
    state = state.copyWith(
      status: ChunkyExecutionStatus.idle,
      currentRun: 0,
      currentRadius: 0,
      totalRuns: 0,
      currentRunProgress: 0,
      totalProgress: 0,
      elapsed: Duration.zero,
      plan: const [],
      hasRecoverableCheckpoint: false,
      logs: const [],
      clearError: true,
      clearStatusMessage: true,
    );
    await refreshTasksPending();
  }

  Future<void> pause() async {
    if (state.status != ChunkyExecutionStatus.running) return;
    _paused = true;
    state = state.copyWith(status: ChunkyExecutionStatus.paused);
    await _persistCheckpoint();
    await _appendLog('Execução pausada manualmente.', level: 'WARN');
  }

  Future<void> resume() async {
    if (state.status != ChunkyExecutionStatus.paused) return;
    _paused = false;
    state = state.copyWith(status: ChunkyExecutionStatus.running);
    await _persistCheckpoint();
    await _appendLog('Execução retomada manualmente.');
  }

  Future<void> cancel() async {
    if (state.status == ChunkyExecutionStatus.idle ||
        state.status == ChunkyExecutionStatus.completed) {
      return;
    }
    _cancelRequested = true;
    _paused = false;
    _pauseAfterCurrentCycleRequested = false;
    _resumeOnNextOnline = false;
    state = state.copyWith(status: ChunkyExecutionStatus.cancelling);
    await _persistCheckpoint();
    await _appendLog('Cancelamento solicitado.', level: 'WARN');
  }

  Future<void> pauseForScheduleConflict() async {
    if (state.status != ChunkyExecutionStatus.running &&
        state.status != ChunkyExecutionStatus.paused) {
      return;
    }
    _pauseAfterCurrentCycleRequested = true;
    _resumeOnNextOnline = true;
    await _appendLog(
      'Pausa solicitada por conflito de agendamento.',
      level: 'WARN',
    );
  }

  Future<void> resumeAfterScheduleIfOnline() async {
    final lifecycle = ref.read(serverRuntimeProvider).lifecycle;
    if (lifecycle != ServerLifecycleState.online) return;
    if (state.status != ChunkyExecutionStatus.paused) return;
    _paused = false;
    state = state.copyWith(status: ChunkyExecutionStatus.running);
    await _persistCheckpoint();
    await _appendLog('Execução retomada após agendamento.');
  }

  Future<void> _runExecutionLoop({
    required ChunkyConfigSettings config,
    required List<int> plan,
    required int startIndex,
    required bool freshStart,
  }) async {
    final runtimeNotifier = ref.read(serverRuntimeProvider.notifier);
    final processService = ref.read(serverProcessServiceProvider);
    final serverPath = ref.read(configFilesProvider).serverPath.trim();
    final backupConfig = ref.read(backupConfigProvider);
    String? previousMaxPlayers;

    try {
      if (freshStart) {
        await _clearTasksDirs(serverPath);
        await _appendLog('Estado antigo de tarefas do Chunky removido.');
      }
      await refreshTasksPending();

      final db = AppDatabase.instance;
      final savedPrevMaxPlayers = await db.getSetting('chunk_prev_max_players');
      final props = await _propertiesService.loadFromFile(serverPath);
      if (props != null) {
        previousMaxPlayers = props.maxPlayers;
        if (previousMaxPlayers.trim().isNotEmpty && previousMaxPlayers != '0') {
          await db.setSetting('chunk_prev_max_players', previousMaxPlayers);
          await _propertiesService.saveToFile(
            serverPath: serverPath,
            settings: props.copyWith(maxPlayers: '0'),
          );
          await _appendLog('max-players ajustado para 0 durante pregen.');
        } else if (savedPrevMaxPlayers != null &&
            savedPrevMaxPlayers.trim().isNotEmpty) {
          previousMaxPlayers = savedPrevMaxPlayers;
        }
      } else {
        previousMaxPlayers = savedPrevMaxPlayers;
      }

      final lifecycleBefore = ref.read(serverRuntimeProvider).lifecycle;
      if (lifecycleBefore == ServerLifecycleState.online) {
        await _appendLog('Parando servidor para preparação inicial.');
        await runtimeNotifier.stopServer();
        final offline = await _waitForOffline();
        if (!offline) {
          throw StateError('Timeout aguardando servidor offline.');
        }
      }

      if (freshStart && state.backupBeforeStart) {
        await _appendLog('Criando backup antes da execução.');
        await ref
            .read(backupServiceProvider)
            .createBackup(
              serverPath: serverPath,
              config: backupConfig,
              trigger: BackupTriggerType.chunk,
            );
      }

      await _appendLog('Iniciando servidor para execução do Chunky.');
      await runtimeNotifier.startServer();
      await _waitForOnline();

      for (var index = startIndex; index < plan.length; index++) {
        if (_cancelRequested) break;
        await _waitWhilePaused();
        if (_cancelRequested) break;

        final runRadius = plan[index];
        final isFirstRun = index == startIndex;
        final continueCurrentRun =
            !freshStart && isFirstRun && await _hasPendingTasks(serverPath);

        if (!continueCurrentRun) {
          await _clearTasksDirs(serverPath);
          await refreshTasksPending();
        }

        _completedRuns = index;
        state = state.copyWith(
          status: ChunkyExecutionStatus.running,
          currentRun: index + 1,
          currentRadius: runRadius,
          currentRunProgress: continueCurrentRun ? state.currentRunProgress : 0,
          totalRuns: plan.length,
          plan: plan,
          clearStatusMessage: true,
        );
        _runElapsedStart = state.elapsed;
        await _persistCheckpoint();
        await _appendLog(
          continueCurrentRun
              ? 'Retomando execução ${index + 1}/${plan.length} (radius $runRadius).'
              : 'Iniciando execução ${index + 1}/${plan.length} (radius $runRadius).',
          runIndex: index + 1,
          totalRuns: plan.length,
          radius: runRadius,
        );

        _runCompleter = Completer<void>();
        if (continueCurrentRun) {
          await runtimeNotifier.sendCommand('chunky continue');
        } else {
          await _sendChunkCommands(config: config, runRadius: runRadius);
        }

        await _runCompleter!.future;
        if (_cancelRequested) break;

        _completedRuns = index + 1;
        final totalProgress = (_completedRuns / plan.length) * 100;
        state = state.copyWith(
          currentRunProgress: 100,
          totalProgress: totalProgress,
        );
        await _persistCheckpoint();
        final runElapsed = state.elapsed - _runElapsedStart;
        await _appendLog(
          'Execução ${index + 1}/${plan.length} concluída em ${_formatDuration(runElapsed)}.',
          runIndex: index + 1,
          totalRuns: plan.length,
          radius: runRadius,
        );

        if (_pauseAfterCurrentCycleRequested) {
          _pauseAfterCurrentCycleRequested = false;
          _paused = true;
          state = state.copyWith(status: ChunkyExecutionStatus.paused);
          await _persistCheckpoint();
          await _appendLog(
            'Execução pausada na fronteira de ciclo.',
            level: 'WARN',
          );
          continue;
        }

        if (_completedRuns < plan.length) {
          final keepServerOnline =
              await _prepareForNextRunWithoutRestartIfPossible(
                processService: processService,
                runtimeNotifier: runtimeNotifier,
                runIndex: index + 1,
                totalRuns: plan.length,
              );
          if (!keepServerOnline) {
            if (_cancelRequested) break;
            await _appendLog(
              'Iniciando próxima execução após reinício do servidor.',
            );
          }
        }
      }

      if (previousMaxPlayers != null &&
          previousMaxPlayers.trim().isNotEmpty &&
          previousMaxPlayers != '0') {
        final propsAfter = await _propertiesService.loadFromFile(serverPath);
        if (propsAfter != null) {
          await _propertiesService.saveToFile(
            serverPath: serverPath,
            settings: propsAfter.copyWith(maxPlayers: previousMaxPlayers),
          );
          await _appendLog('max-players restaurado para $previousMaxPlayers.');
          final lifecycle = ref.read(serverRuntimeProvider).lifecycle;
          if (lifecycle == ServerLifecycleState.online) {
            await _appendLog(
              'Reiniciando servidor para aplicar max-players restaurado.',
            );
            await runtimeNotifier.restartServer();
            await _waitForOnline();
          }
        }
      }

      if (_cancelRequested) {
        state = state.copyWith(
          status: ChunkyExecutionStatus.idle,
          currentRun: 0,
          currentRadius: 0,
          totalRuns: 0,
          currentRunProgress: 0,
          totalProgress: 0,
          elapsed: Duration.zero,
          plan: const [],
          hasRecoverableCheckpoint: false,
          clearStatusMessage: true,
        );
        await _clearCheckpoint();
        await _appendLog('Execução cancelada.');
      } else {
        await _clearTasksDirs(serverPath);
        state = state.copyWith(
          status: ChunkyExecutionStatus.completed,
          currentRunProgress: 100,
          totalProgress: 100,
          hasRecoverableCheckpoint: false,
          statusMessage: 'Execução concluída com sucesso.',
        );
        await _clearCheckpoint();
        await _appendLog('Plano concluído com sucesso.');
      }
    } catch (error) {
      state = state.copyWith(
        status: ChunkyExecutionStatus.awaitingResume,
        hasRecoverableCheckpoint: true,
        errorMessage: error.toString(),
        statusMessage:
            'Execução interrompida. Revise o status do servidor e escolha Continuar ou Reiniciar.',
      );
      await _persistCheckpoint();
      await _appendLog('Erro durante execução: $error', level: 'ERROR');
    } finally {
      _elapsedTimer?.cancel();
      _runCompleter = null;
      _cancelRequested = false;
      if (state.status != ChunkyExecutionStatus.paused) {
        _paused = false;
      }
      await refreshTasksPending();
    }
  }

  Future<bool> _prepareForNextRunWithoutRestartIfPossible({
    required ServerProcessService processService,
    required ServerRuntimeNotifier runtimeNotifier,
    required int runIndex,
    required int totalRuns,
  }) async {
    await _appendLog(
      'Execução $runIndex/$totalRuns atingiu 100%. Aguardando $_gcPauseSeconds segundos para GC.',
      runIndex: runIndex,
      totalRuns: totalRuns,
      radius: state.currentRadius,
    );
    await Future<void>.delayed(const Duration(seconds: _gcPauseSeconds));

    final saveAck = await _sendSaveAllAndAwaitAck(
      runtimeNotifier,
      timeout: const Duration(seconds: _saveAllAckTimeoutSeconds),
    );
    if (!saveAck) {
      await _appendLog(
        'save-all sem confirmação explícita no timeout. Continuando fluxo com cautela.',
        level: 'WARN',
        runIndex: runIndex,
        totalRuns: totalRuns,
        radius: state.currentRadius,
      );
    }

    final initialRamMb = await processService.getActiveServerMemoryMb();
    if (initialRamMb == null) {
      await _appendLog(
        'Não foi possível ler RAM do servidor. Reinício será aplicado por segurança.',
        level: 'WARN',
        runIndex: runIndex,
        totalRuns: totalRuns,
        radius: state.currentRadius,
      );
      await _restartServerBetweenRuns(runtimeNotifier);
      return false;
    }

    await _appendLog(
      'RAM inicial após save-all: ${_formatMb(initialRamMb)}. Observando por $_memoryObserveSeconds segundos.',
      runIndex: runIndex,
      totalRuns: totalRuns,
      radius: state.currentRadius,
    );

    var safeToContinue = false;
    for (
      var elapsed = _memoryObserveStepSeconds;
      elapsed <= _memoryObserveSeconds;
      elapsed += _memoryObserveStepSeconds
    ) {
      await Future<void>.delayed(
        const Duration(seconds: _memoryObserveStepSeconds),
      );
      final current = await processService.getActiveServerMemoryMb();
      if (current == null) {
        continue;
      }
      await _appendLog(
        'RAM monitorada em ${elapsed}s: ${_formatMb(current)}.',
        runIndex: runIndex,
        totalRuns: totalRuns,
        radius: state.currentRadius,
      );

      if (current < initialRamMb && current <= _memoryStableThresholdMb) {
        safeToContinue = true;
        await _appendLog(
          'RAM abaixo do limite (${_formatMb(_memoryStableThresholdMb)}). Próxima task seguirá sem reinício.',
          runIndex: runIndex,
          totalRuns: totalRuns,
          radius: state.currentRadius,
        );
        break;
      }
    }

    if (safeToContinue) {
      return true;
    }

    await _appendLog(
      'RAM não reduziu o suficiente em $_memoryObserveSeconds segundos. Reiniciando servidor.',
      level: 'WARN',
      runIndex: runIndex,
      totalRuns: totalRuns,
      radius: state.currentRadius,
    );
    await _restartServerBetweenRuns(runtimeNotifier);
    return false;
  }

  Future<void> _restartServerBetweenRuns(
    ServerRuntimeNotifier runtimeNotifier,
  ) async {
    await runtimeNotifier.sendCommand('stop');
    final graceful = await _waitForOffline(
      timeout: const Duration(seconds: 15),
    );
    if (!graceful) {
      await _appendLog(
        'Timeout no stop gracioso. Forçando encerramento do processo.',
        level: 'WARN',
      );
      await runtimeNotifier.stopServer();
      final offline = await _waitForOffline();
      if (!offline) {
        throw StateError(
          'Timeout aguardando servidor offline após forçar stop.',
        );
      }
    }

    final waitSecRaw = ref.read(configFilesProvider).restartWaitSeconds.trim();
    final waitSec = int.tryParse(waitSecRaw) ?? 10;
    final boundedWait = waitSec.clamp(0, 300);
    if (boundedWait > 0) {
      await _appendLog(
        'Aguardando $boundedWait segundos antes de subir o servidor novamente.',
      );
      await Future<void>.delayed(Duration(seconds: boundedWait));
    }

    if (_cancelRequested) return;
    await runtimeNotifier.startServer();
    await _waitForOnline();
    await _appendLog('Servidor reiniciado e pronto para próxima execução.');
  }

  Future<bool> _sendSaveAllAndAwaitAck(
    ServerRuntimeNotifier runtimeNotifier, {
    required Duration timeout,
  }) async {
    _saveAllCompleter = Completer<bool>();
    await _appendLog('Executando comando save-all e aguardando confirmação.');
    await runtimeNotifier.sendCommand('save-all');

    final result = await Future.any<bool>([
      _saveAllCompleter!.future,
      Future<bool>.delayed(timeout, () => false),
    ]);
    _saveAllCompleter = null;
    if (result) {
      await _appendLog('save-all confirmado pelo servidor.');
    }
    return result;
  }

  Future<void> _waitWhilePaused() async {
    while (_paused && !_cancelRequested) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }

  Future<void> _sendChunkCommands({
    required ChunkyConfigSettings config,
    required int runRadius,
  }) async {
    final runtimeNotifier = ref.read(serverRuntimeProvider.notifier);
    await runtimeNotifier.sendCommand(
      'chunky center ${config.centerX} ${config.centerZ}',
    );
    await runtimeNotifier.sendCommand(
      _buildRadiusCommand(
        radius: runRadius,
        shape: config.shape,
        mode: config.radiusMode,
      ),
    );
    await runtimeNotifier.sendCommand('chunky pattern ${config.pattern}');
    await runtimeNotifier.sendCommand('chunky shape ${config.shape}');
    await runtimeNotifier.sendCommand('chunky start');
  }

  String _buildRadiusCommand({
    required int radius,
    required String shape,
    required String mode,
  }) {
    final lowerShape = shape.toLowerCase();
    final useDouble = switch (mode) {
      'double' => true,
      'single' => false,
      _ => lowerShape == 'rectangle' || lowerShape == 'ellipse',
    };
    if (useDouble) {
      return 'chunky radius $radius $radius';
    }
    return 'chunky radius $radius';
  }

  Future<void> _waitForOnline() async {
    for (var i = 0; i < 400; i++) {
      final lifecycle = ref.read(serverRuntimeProvider).lifecycle;
      if (lifecycle == ServerLifecycleState.online) return;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    throw StateError('Timeout aguardando servidor online.');
  }

  Future<bool> _waitForOffline({
    Duration timeout = const Duration(seconds: 100),
  }) async {
    final attempts = (timeout.inMilliseconds / 250).ceil();
    for (var i = 0; i < attempts; i++) {
      final lifecycle = ref.read(serverRuntimeProvider).lifecycle;
      if (lifecycle == ServerLifecycleState.offline ||
          lifecycle == ServerLifecycleState.error) {
        return true;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    return false;
  }

  Future<bool> _hasPendingTasks(String serverPath) async {
    if (serverPath.isEmpty) return false;
    final dirs = <Directory>[
      Directory(p.join(serverPath, 'config', 'Chunky', 'Tasks')),
      Directory(p.join(serverPath, 'config', 'Chunky', 'tasks')),
    ];
    for (final dir in dirs) {
      if (!await dir.exists()) continue;
      await for (final _ in dir.list(followLinks: false)) {
        return true;
      }
    }
    return false;
  }

  Future<void> _clearTasksDirs(String serverPath) async {
    if (serverPath.isEmpty) return;
    final dirs = <Directory>[
      Directory(p.join(serverPath, 'config', 'Chunky', 'Tasks')),
      Directory(p.join(serverPath, 'config', 'Chunky', 'tasks')),
    ];
    for (final dir in dirs) {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    }
  }

  void _handleStdoutLine(String line) {
    final lowerLine = line.toLowerCase();
    if (_saveAllCompleter != null && _looksLikeSaveAllAck(lowerLine)) {
      if (!(_saveAllCompleter?.isCompleted ?? true)) {
        _saveAllCompleter?.complete(true);
      }
    }

    if (state.status != ChunkyExecutionStatus.running &&
        state.status != ChunkyExecutionStatus.paused) {
      return;
    }
    if (!lowerLine.contains('chunk')) {
      return;
    }

    if (lowerLine.contains('task finished')) {
      state = state.copyWith(currentRunProgress: 100);
      _runCompleter?.complete();
      _runCompleter = null;
      unawaited(_persistCheckpoint());
      return;
    }

    final percentMatch = RegExp(r'(\d{1,3}(?:[.,]\d+)?)%').firstMatch(line);
    if (percentMatch != null) {
      final parsed = double.tryParse(
        percentMatch.group(1)!.replaceAll(',', '.'),
      );
      if (parsed != null) {
        final bounded = parsed.clamp(0, 100).toDouble();
        final totalRuns = state.totalRuns == 0 ? 1 : state.totalRuns;
        final total = ((_completedRuns + (bounded / 100)) / totalRuns) * 100;
        state = state.copyWith(
          currentRunProgress: bounded,
          totalProgress: total.clamp(0, 100).toDouble(),
        );
        if (bounded >= 100) {
          _runCompleter?.complete();
          _runCompleter = null;
        }
      }
    }
  }

  bool _looksLikeSaveAllAck(String line) {
    if (line.contains('saved the game')) return true;
    if (line.contains('saved the world')) return true;
    if (line.contains('saved') && line.contains('game')) return true;
    return false;
  }

  void _startElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.status == ChunkyExecutionStatus.running) {
        state = state.copyWith(
          elapsed: state.elapsed + const Duration(seconds: 1),
        );
      }
    });
  }

  Future<void> _appendLog(
    String message, {
    String level = 'INFO',
    int? runIndex,
    int? totalRuns,
    int? radius,
  }) async {
    final db = await AppDatabase.instance.database;
    final now = DateTime.now();
    final resolvedRun = runIndex ?? state.currentRun;
    final resolvedTotal = totalRuns ?? state.totalRuns;
    final resolvedRadius = radius ?? state.currentRadius;
    final elapsedSeconds = state.elapsed.inSeconds;

    final insertedId = await db.insert('chunky_logs', {
      'level': level,
      'message': message,
      'run_index': resolvedRun,
      'total_runs': resolvedTotal,
      'radius': resolvedRadius,
      'elapsed_seconds': elapsedSeconds,
      'created_at': now.toIso8601String(),
    });

    final entry = ChunkyExecutionLogEntry(
      id: insertedId,
      timestamp: now,
      level: level,
      message: message,
      runIndex: resolvedRun,
      totalRuns: resolvedTotal,
      radius: resolvedRadius,
      elapsed: Duration(seconds: elapsedSeconds),
    );

    final next = <ChunkyExecutionLogEntry>[...state.logs, entry];
    if (next.length > 1000) {
      next.removeRange(0, next.length - 1000);
    }
    state = state.copyWith(logs: next);
  }

  Future<void> _loadLogsFromDb() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('chunky_logs', orderBy: 'id ASC', limit: 1000);

    final logs = rows.map((row) {
      return ChunkyExecutionLogEntry(
        id: row['id'] as int,
        timestamp:
            DateTime.tryParse(row['created_at'] as String? ?? '') ??
            DateTime.now(),
        level: (row['level'] as String? ?? 'INFO').toUpperCase(),
        message: row['message'] as String? ?? '',
        runIndex: row['run_index'] as int? ?? 0,
        totalRuns: row['total_runs'] as int? ?? 0,
        radius: row['radius'] as int? ?? 0,
        elapsed: Duration(seconds: row['elapsed_seconds'] as int? ?? 0),
      );
    }).toList();

    state = state.copyWith(logs: logs);
  }

  Future<void> _clearLogs() async {
    final db = await AppDatabase.instance.database;
    await db.delete('chunky_logs');
  }

  Future<void> _persistCheckpoint() async {
    final db = AppDatabase.instance;
    await db.setSetting('chunk_exec_exists', '1');
    await db.setSetting('chunk_exec_status', state.status.name);
    await db.setSetting('chunk_exec_current_run', '${state.currentRun}');
    await db.setSetting('chunk_exec_current_radius', '${state.currentRadius}');
    await db.setSetting('chunk_exec_total_runs', '${state.totalRuns}');
    await db.setSetting(
      'chunk_exec_current_progress',
      state.currentRunProgress.toStringAsFixed(3),
    );
    await db.setSetting(
      'chunk_exec_total_progress',
      state.totalProgress.toStringAsFixed(3),
    );
    await db.setSetting(
      'chunk_exec_elapsed_seconds',
      '${state.elapsed.inSeconds}',
    );
    await db.setSetting('chunk_exec_plan', state.plan.join(','));
  }

  Future<_ChunkyCheckpoint?> _loadCheckpoint() async {
    final db = AppDatabase.instance;
    final exists = await db.getSetting('chunk_exec_exists');
    if (exists != '1') {
      return null;
    }

    final planRaw = await db.getSetting('chunk_exec_plan') ?? '';
    final plan = planRaw
        .split(',')
        .map((value) => int.tryParse(value.trim()))
        .whereType<int>()
        .toList();
    if (plan.isEmpty) {
      return null;
    }

    final statusRaw = await db.getSetting('chunk_exec_status') ?? '';
    var status = ChunkyExecutionStatus.awaitingResume;
    for (final candidate in ChunkyExecutionStatus.values) {
      if (candidate.name == statusRaw) {
        status = candidate;
        break;
      }
    }

    return _ChunkyCheckpoint(
      status: status,
      currentRun:
          int.tryParse(await db.getSetting('chunk_exec_current_run') ?? '') ??
          1,
      currentRadius:
          int.tryParse(
            await db.getSetting('chunk_exec_current_radius') ?? '',
          ) ??
          0,
      totalRuns:
          int.tryParse(await db.getSetting('chunk_exec_total_runs') ?? '') ??
          plan.length,
      currentRunProgress:
          double.tryParse(
            await db.getSetting('chunk_exec_current_progress') ?? '',
          ) ??
          0,
      totalProgress:
          double.tryParse(
            await db.getSetting('chunk_exec_total_progress') ?? '',
          ) ??
          0,
      elapsedSeconds:
          int.tryParse(
            await db.getSetting('chunk_exec_elapsed_seconds') ?? '',
          ) ??
          0,
      plan: plan,
    );
  }

  Future<void> _clearCheckpoint() async {
    final db = AppDatabase.instance;
    await db.setSetting('chunk_exec_exists', '0');
    await db.setSetting('chunk_exec_status', '');
    await db.setSetting('chunk_exec_current_run', '0');
    await db.setSetting('chunk_exec_current_radius', '0');
    await db.setSetting('chunk_exec_total_runs', '0');
    await db.setSetting('chunk_exec_current_progress', '0');
    await db.setSetting('chunk_exec_total_progress', '0');
    await db.setSetting('chunk_exec_elapsed_seconds', '0');
    await db.setSetting('chunk_exec_plan', '');
  }

  String _formatMb(int mb) {
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(2)} GB';
  }

  String _formatDuration(Duration duration) {
    final hh = duration.inHours.toString().padLeft(2, '0');
    final mm = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final ss = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }
}

class _ChunkyCheckpoint {
  const _ChunkyCheckpoint({
    required this.status,
    required this.currentRun,
    required this.currentRadius,
    required this.totalRuns,
    required this.currentRunProgress,
    required this.totalProgress,
    required this.elapsedSeconds,
    required this.plan,
  });

  final ChunkyExecutionStatus status;
  final int currentRun;
  final int currentRadius;
  final int totalRuns;
  final double currentRunProgress;
  final double totalProgress;
  final int elapsedSeconds;
  final List<int> plan;
}
