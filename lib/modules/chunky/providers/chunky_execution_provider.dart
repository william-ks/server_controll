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
    required this.totalRuns,
    required this.currentRunProgress,
    required this.totalProgress,
    required this.elapsed,
    required this.plan,
    required this.tasksPending,
    required this.backupBeforeStart,
    this.errorMessage,
  });

  final ChunkyExecutionStatus status;
  final int currentRun;
  final int totalRuns;
  final double currentRunProgress;
  final double totalProgress;
  final Duration elapsed;
  final List<int> plan;
  final bool tasksPending;
  final bool backupBeforeStart;
  final String? errorMessage;

  ChunkyExecutionState copyWith({
    ChunkyExecutionStatus? status,
    int? currentRun,
    int? totalRuns,
    double? currentRunProgress,
    double? totalProgress,
    Duration? elapsed,
    List<int>? plan,
    bool? tasksPending,
    bool? backupBeforeStart,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ChunkyExecutionState(
      status: status ?? this.status,
      currentRun: currentRun ?? this.currentRun,
      totalRuns: totalRuns ?? this.totalRuns,
      currentRunProgress: currentRunProgress ?? this.currentRunProgress,
      totalProgress: totalProgress ?? this.totalProgress,
      elapsed: elapsed ?? this.elapsed,
      plan: plan ?? this.plan,
      tasksPending: tasksPending ?? this.tasksPending,
      backupBeforeStart: backupBeforeStart ?? this.backupBeforeStart,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  factory ChunkyExecutionState.initial() {
    return const ChunkyExecutionState(
      status: ChunkyExecutionStatus.idle,
      currentRun: 0,
      totalRuns: 0,
      currentRunProgress: 0,
      totalProgress: 0,
      elapsed: Duration.zero,
      plan: [],
      tasksPending: false,
      backupBeforeStart: false,
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
  int _completedRuns = 0;

  @override
  ChunkyExecutionState build() {
    _stdoutSub = ref
        .read(serverProcessServiceProvider)
        .stdoutLines
        .listen(_handleStdoutLine);
    Future<void>(() => _bootstrap());

    ref.onDispose(() {
      _elapsedTimer?.cancel();
      unawaited(_stdoutSub?.cancel());
    });

    return ChunkyExecutionState.initial();
  }

  Future<void> _bootstrap() async {
    final backupBeforeStart = ref.read(chunkyConfigProvider).backupBeforeStart;
    await refreshTasksPending();
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
    var remaining = radius;
    while (remaining > 0) {
      final run = remaining > maxPerRun ? maxPerRun : remaining;
      plan.add(run);
      remaining -= run;
    }
    return plan;
  }

  Future<void> startExecution() async {
    if (state.status == ChunkyExecutionStatus.running ||
        state.status == ChunkyExecutionStatus.paused ||
        state.status == ChunkyExecutionStatus.cancelling) {
      return;
    }

    final runtime = ref.read(serverRuntimeProvider);
    if (runtime.lifecycle != ServerLifecycleState.online) {
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
    _completedRuns = 0;
    state = state.copyWith(
      status: ChunkyExecutionStatus.running,
      currentRun: 1,
      totalRuns: plan.length,
      plan: plan,
      currentRunProgress: 0,
      totalProgress: 0,
      elapsed: Duration.zero,
      clearError: true,
    );
    _startElapsedTimer();

    Future<void>(() => _runExecutionLoop(config, plan));
  }

  Future<void> pause() async {
    if (state.status != ChunkyExecutionStatus.running) return;
    _paused = true;
    state = state.copyWith(status: ChunkyExecutionStatus.paused);
  }

  Future<void> resume() async {
    if (state.status != ChunkyExecutionStatus.paused) return;
    _paused = false;
    state = state.copyWith(status: ChunkyExecutionStatus.running);
  }

  Future<void> cancel() async {
    if (state.status == ChunkyExecutionStatus.idle ||
        state.status == ChunkyExecutionStatus.completed) {
      return;
    }
    _cancelRequested = true;
    _paused = false;
    state = state.copyWith(status: ChunkyExecutionStatus.cancelling);
  }

  Future<void> _runExecutionLoop(
    ChunkyConfigSettings config,
    List<int> plan,
  ) async {
    final runtimeNotifier = ref.read(serverRuntimeProvider.notifier);
    final serverPath = ref.read(configFilesProvider).serverPath.trim();
    final backupConfig = ref.read(backupConfigProvider);
    String? previousMaxPlayers;

    try {
      await _clearTasksDir(serverPath);
      await refreshTasksPending();

      final props = await _propertiesService.loadFromFile(serverPath);
      if (props != null) {
        previousMaxPlayers = props.maxPlayers;
        await AppDatabase.instance.setSetting(
          'chunk_prev_max_players',
          previousMaxPlayers,
        );
        await _propertiesService.saveToFile(
          serverPath: serverPath,
          settings: props.copyWith(maxPlayers: '0'),
        );
      }

      final lifecycleBefore = ref.read(serverRuntimeProvider).lifecycle;
      if (lifecycleBefore == ServerLifecycleState.online) {
        await runtimeNotifier.stopServer();
        await _waitForOffline();
      }

      if (state.backupBeforeStart) {
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

      for (var index = 0; index < plan.length; index++) {
        if (_cancelRequested) break;
        await _waitWhilePaused();
        if (_cancelRequested) break;

        final runRadius = plan[index];
        state = state.copyWith(
          status: ChunkyExecutionStatus.running,
          currentRun: index + 1,
          currentRunProgress: 0,
          elapsed: Duration.zero,
        );
        _runCompleter = Completer<void>();

        await _sendChunkCommands(config: config, runRadius: runRadius);
        await _runCompleter!.future;
        if (_cancelRequested) break;

        _completedRuns = index + 1;
        final totalProgress = (_completedRuns / plan.length) * 100;
        state = state.copyWith(
          currentRunProgress: 100,
          totalProgress: totalProgress,
        );

        if (_completedRuns < plan.length) {
          await runtimeNotifier.stopServer();
          await _waitForOffline();
          await Future<void>.delayed(const Duration(seconds: 10));
          if (_cancelRequested) break;
          await runtimeNotifier.startServer();
          await _waitForOnline();
        }
      }

      if (previousMaxPlayers != null && previousMaxPlayers.trim().isNotEmpty) {
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
          totalRuns: 0,
          currentRunProgress: 0,
          totalProgress: 0,
          elapsed: Duration.zero,
          plan: const [],
        );
      } else {
        state = state.copyWith(
          status: ChunkyExecutionStatus.completed,
          currentRunProgress: 100,
          totalProgress: 100,
        );
      }
    } catch (error) {
      state = state.copyWith(
        status: ChunkyExecutionStatus.error,
        errorMessage: error.toString(),
      );
    } finally {
      _elapsedTimer?.cancel();
      _runCompleter = null;
      _cancelRequested = false;
      _paused = false;
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
    final tasksDir = Directory(p.join(serverPath, 'config', 'Chunky', 'Tasks'));
    if (!await tasksDir.exists()) return false;
    await for (final _ in tasksDir.list(followLinks: false)) {
      return true;
    }
    return false;
  }

  Future<void> _clearTasksDir(String serverPath) async {
    if (serverPath.isEmpty) return;
    final tasksDir = Directory(p.join(serverPath, 'config', 'Chunky', 'Tasks'));
    if (await tasksDir.exists()) {
      await tasksDir.delete(recursive: true);
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

    final percentMatch = RegExp(r'(\d{1,3}(?:\.\d+)?)%').firstMatch(line);
    if (percentMatch != null) {
      final parsed = double.tryParse(percentMatch.group(1)!);
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
}
