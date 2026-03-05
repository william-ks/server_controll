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
import '../models/chunky_config_settings.dart';
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
    );
  }
}

final chunkyExecutionProvider =
    NotifierProvider<ChunkyExecutionNotifier, ChunkyExecutionState>(
      ChunkyExecutionNotifier.new,
    );

class ChunkyExecutionNotifier extends Notifier<ChunkyExecutionState> {
  final ServerPropertiesService _propertiesService = ServerPropertiesService();
  StreamSubscription<String>? _stdoutSub;
  Timer? _elapsedTimer;
  Completer<void>? _runCompleter;
  bool _cancelRequested = false;
  bool _paused = false;
  bool _pauseAfterCurrentCycleRequested = false;
  bool _resumeOnNextOnline = false;
  int _completedRuns = 0;

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
  }

  Future<void> resume() async {
    if (state.status != ChunkyExecutionStatus.paused) return;
    _paused = false;
    state = state.copyWith(status: ChunkyExecutionStatus.running);
    await _persistCheckpoint();
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
  }

  Future<void> pauseForScheduleConflict() async {
    if (state.status != ChunkyExecutionStatus.running &&
        state.status != ChunkyExecutionStatus.paused) {
      return;
    }
    _pauseAfterCurrentCycleRequested = true;
    _resumeOnNextOnline = true;
  }

  Future<void> resumeAfterScheduleIfOnline() async {
    final lifecycle = ref.read(serverRuntimeProvider).lifecycle;
    if (lifecycle != ServerLifecycleState.online) return;
    if (state.status != ChunkyExecutionStatus.paused) return;
    _paused = false;
    state = state.copyWith(status: ChunkyExecutionStatus.running);
    await _persistCheckpoint();
  }

  Future<void> _runExecutionLoop({
    required ChunkyConfigSettings config,
    required List<int> plan,
    required int startIndex,
    required bool freshStart,
  }) async {
    final runtimeNotifier = ref.read(serverRuntimeProvider.notifier);
    final serverPath = ref.read(configFilesProvider).serverPath.trim();
    final backupConfig = ref.read(backupConfigProvider);
    String? previousMaxPlayers;

    try {
      if (freshStart) {
        await _clearTasksDirs(serverPath);
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
        } else if (savedPrevMaxPlayers != null &&
            savedPrevMaxPlayers.trim().isNotEmpty) {
          previousMaxPlayers = savedPrevMaxPlayers;
        }
      } else {
        previousMaxPlayers = savedPrevMaxPlayers;
      }

      final lifecycleBefore = ref.read(serverRuntimeProvider).lifecycle;
      if (lifecycleBefore == ServerLifecycleState.online) {
        await runtimeNotifier.stopServer();
        await _waitForOffline();
      }

      if (freshStart && state.backupBeforeStart) {
        await ref
            .read(backupServiceProvider)
            .createBackup(
              serverPath: serverPath,
              config: backupConfig,
              trigger: BackupTriggerType.chunk,
            );
      }

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
        await _persistCheckpoint();

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

        if (_pauseAfterCurrentCycleRequested) {
          _pauseAfterCurrentCycleRequested = false;
          _paused = true;
          state = state.copyWith(status: ChunkyExecutionStatus.paused);
          await _persistCheckpoint();
          continue;
        }

        if (_completedRuns < plan.length) {
          await runtimeNotifier.sendCommand('stop');
          await _waitForOffline();
          await Future<void>.delayed(const Duration(seconds: 5));
          if (_cancelRequested) break;
          await runtimeNotifier.startServer();
          await _waitForOnline();
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
          final lifecycle = ref.read(serverRuntimeProvider).lifecycle;
          if (lifecycle == ServerLifecycleState.online) {
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

  Future<void> _waitForOffline() async {
    for (var i = 0; i < 400; i++) {
      final lifecycle = ref.read(serverRuntimeProvider).lifecycle;
      if (lifecycle == ServerLifecycleState.offline ||
          lifecycle == ServerLifecycleState.error) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    throw StateError('Timeout aguardando servidor offline.');
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
    if (state.status != ChunkyExecutionStatus.running &&
        state.status != ChunkyExecutionStatus.paused) {
      return;
    }
    if (!line.toLowerCase().contains('chunk')) {
      return;
    }

    if (line.toLowerCase().contains('task finished')) {
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
