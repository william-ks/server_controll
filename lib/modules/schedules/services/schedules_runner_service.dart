import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/server_lifecycle_state.dart';
import '../../backup/models/backup_config_settings.dart';
import '../../backup/providers/backup_config_provider.dart';
import '../../backup/providers/backups_provider.dart';
import '../../backup/services/backup_service.dart';
import '../../config/providers/config_files_provider.dart';
import '../../chunky/models/chunky_execution_status.dart';
import '../../chunky/providers/chunky_execution_provider.dart';
import '../../server/providers/server_runtime_provider.dart';
import '../models/schedule_action.dart';
import '../models/schedule_item.dart';
import '../providers/schedules_provider.dart';
import 'cron_matcher.dart';

final schedulesRunnerProvider = Provider<SchedulesRunnerService>((ref) {
  final service = SchedulesRunnerService(ref);
  service.start();
  ref.onDispose(service.dispose);
  return service;
});

class SchedulesRunnerService {
  SchedulesRunnerService(this._ref);

  final Ref _ref;

  Timer? _tickTimer;
  bool _runningTick = false;
  final Map<int, String> _lastExecutionKey = {};
  final Map<int, Set<String>> _sentWarnings = {};

  void start() {
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      unawaited(_tick());
    });
    unawaited(_tick());
  }

  void dispose() {
    _tickTimer?.cancel();
  }

  Future<void> _tick() async {
    if (_runningTick) return;
    _runningTick = true;
    try {
      final schedules = _ref
          .read(schedulesProvider)
          .items
          .where((item) => item.isActive)
          .toList();
      if (schedules.isEmpty) return;

      final now = DateTime.now();
      for (final schedule in schedules) {
        await _handleWarnings(schedule, now);
        await _handleExecution(schedule, now);
      }
    } finally {
      _runningTick = false;
    }
  }

  Future<void> _handleWarnings(ScheduleItem schedule, DateTime now) async {
    final next = CronMatcher.nextOccurrence(schedule.cronExpression, now);
    if (next == null) return;

    final remainingMinutes = next.difference(now).inMinutes;
    const warningOffsets = {15, 10, 5, 1};
    if (!warningOffsets.contains(remainingMinutes)) return;

    final runtime = _ref.read(serverRuntimeProvider);
    if (runtime.activePlayers < 1) return;

    final scheduleId = schedule.id;
    if (scheduleId == null) return;

    final occurrenceKey = '${next.millisecondsSinceEpoch}-$remainingMinutes';
    final sent = _sentWarnings.putIfAbsent(scheduleId, () => <String>{});
    if (sent.contains(occurrenceKey)) return;

    final actionLabel = switch (schedule.action) {
      ScheduleAction.startServer => 'iniciado',
      ScheduleAction.restartServer => 'reiniciado',
      ScheduleAction.stopServer => 'desligado',
    };
    await _sendServerMessage(
      'O servidor será $actionLabel em $remainingMinutes minuto(s). Procure um abrigo.',
    );
    sent.add(occurrenceKey);
  }

  Future<void> _handleExecution(ScheduleItem schedule, DateTime now) async {
    if (!CronMatcher.matches(schedule.cronExpression, now)) {
      return;
    }

    final scheduleId = schedule.id;
    if (scheduleId == null) return;

    final minuteKey = _minuteKey(now);
    if (_lastExecutionKey[scheduleId] == minuteKey) {
      return;
    }
    _lastExecutionKey[scheduleId] = minuteKey;

    await _executeSchedule(schedule);
  }

  Future<void> _executeSchedule(ScheduleItem schedule) async {
    final runtimeNotifier = _ref.read(serverRuntimeProvider.notifier);
    final chunkyNotifier = _ref.read(chunkyExecutionProvider.notifier);
    final config = _ref.read(configFilesProvider);
    final backupConfig = _ref.read(backupConfigProvider);
    final backupAllowed = await _isBackupAllowed(backupConfig);
    final shouldBackup = schedule.withBackup && backupAllowed;

    try {
      final chunkyState = _ref.read(chunkyExecutionProvider);
      final chunkyRunning =
          chunkyState.status == ChunkyExecutionStatus.running ||
          chunkyState.status == ChunkyExecutionStatus.paused;
      if (chunkyRunning) {
        await chunkyNotifier.pauseForScheduleConflict();
        await _waitForChunkyPauseBoundary();
      }

      switch (schedule.action) {
        case ScheduleAction.startServer:
          if (shouldBackup) {
            await _runBackup(config.serverPath.trim(), backupConfig);
          }
          await runtimeNotifier.startServer();
        case ScheduleAction.stopServer:
          await runtimeNotifier.stopServer();
          await _waitForOffline();
          if (shouldBackup) {
            await _runBackup(config.serverPath.trim(), backupConfig);
          }
        case ScheduleAction.restartServer:
          await runtimeNotifier.stopServer();
          await _waitForOffline();
          if (shouldBackup) {
            await _runBackup(config.serverPath.trim(), backupConfig);
          }
          await runtimeNotifier.startServer();
      }

      final runtime = _ref.read(serverRuntimeProvider);
      if (runtime.lifecycle == ServerLifecycleState.online) {
        await chunkyNotifier.resumeAfterScheduleIfOnline();
      }

      if (schedule.id != null) {
        await _ref.read(schedulesProvider.notifier).markExecuted(schedule.id!);
      }
    } catch (_) {
      // Silent by design for background runner.
    }
  }

  Future<void> _waitForChunkyPauseBoundary() async {
    for (var i = 0; i < 240; i++) {
      final state = _ref.read(chunkyExecutionProvider);
      if (state.status == ChunkyExecutionStatus.paused ||
          state.status == ChunkyExecutionStatus.idle ||
          state.status == ChunkyExecutionStatus.completed ||
          state.status == ChunkyExecutionStatus.error) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }

  Future<void> _runBackup(
    String serverPath,
    BackupConfigSettings backupConfig,
  ) async {
    final service = _ref.read(backupServiceProvider);
    await service.createBackup(
      serverPath: serverPath,
      config: backupConfig,
      trigger: BackupTriggerType.schedule,
    );
  }

  Future<bool> _isBackupAllowed(BackupConfigSettings config) async {
    if (!config.backupsEnabled) return false;
    final path = config.backupPath.trim();
    if (path.isEmpty) return false;
    return Directory(path).existsSync();
  }

  Future<void> _waitForOffline() async {
    for (var i = 0; i < 240; i++) {
      final lifecycle = _ref.read(serverRuntimeProvider).lifecycle;
      if (lifecycle == ServerLifecycleState.offline ||
          lifecycle == ServerLifecycleState.error) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }

  Future<void> _sendServerMessage(String message) async {
    final runtimeNotifier = _ref.read(serverRuntimeProvider.notifier);
    await runtimeNotifier.sendCommand('say [Server] $message');
  }

  String _minuteKey(DateTime dt) {
    return '${dt.year}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}${dt.hour.toString().padLeft(2, '0')}${dt.minute.toString().padLeft(2, '0')}';
  }
}
