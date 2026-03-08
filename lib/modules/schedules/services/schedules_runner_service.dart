import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../../../models/server_lifecycle_state.dart';
import '../../backup/models/backup_config_settings.dart';
import '../../backup/providers/auto_backup_status_provider.dart';
import '../../backup/providers/app_backups_provider.dart';
import '../../backup/providers/backup_config_provider.dart';
import '../../backup/providers/backups_provider.dart';
import '../../backup/repositories/automatic_backup_history_repository.dart';
import '../../backup/services/backup_service.dart';
import '../../config/providers/config_files_provider.dart';
import '../../chunky/models/chunky_execution_status.dart';
import '../../chunky/providers/chunky_execution_provider.dart';
import '../../server/providers/server_runtime_provider.dart';
import '../../server/services/minecraft_command_provider.dart';
import '../models/schedule_action.dart';
import '../models/schedule_backup_kind.dart';
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

  static const _commands = MinecraftCommandProvider.vanilla;
  static const _maxBackupAttempts = 3;
  static const _defaultRetryIntervalSeconds = 10;
  final Ref _ref;

  Timer? _tickTimer;
  bool _runningTick = false;
  bool _automaticBackupInProgress = false;
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
    final shouldBackup = schedule.withBackup;

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
            await _sendSaveAllIfNeeded(schedule.backupKind);
            await _runScheduledBackupWithRetry(
              schedule: schedule,
              serverPath: config.serverPath.trim(),
              backupConfig: backupConfig,
            );
          }
          await runtimeNotifier.startServer();
        case ScheduleAction.stopServer:
          if (shouldBackup) {
            await _sendSaveAllIfNeeded(schedule.backupKind);
          }
          await runtimeNotifier.stopServer();
          await _waitForOffline();
          if (shouldBackup) {
            await _runScheduledBackupWithRetry(
              schedule: schedule,
              serverPath: config.serverPath.trim(),
              backupConfig: backupConfig,
            );
          }
        case ScheduleAction.restartServer:
          if (shouldBackup) {
            await _sendSaveAllIfNeeded(schedule.backupKind);
          }
          await runtimeNotifier.stopServer();
          await _waitForOffline();
          if (shouldBackup) {
            await _runScheduledBackupWithRetry(
              schedule: schedule,
              serverPath: config.serverPath.trim(),
              backupConfig: backupConfig,
            );
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
    } catch (error) {
      await _logAutomaticBackup(
        schedule: schedule,
        attempt: 0,
        resultStatus: 'schedule_error',
        message: _normalizeError(error),
      );
      // Silent by design for background runner.
    }
  }

  Future<void> _waitForChunkyPauseBoundary() async {
    for (var i = 0; i < 240; i++) {
      final state = _ref.read(chunkyExecutionProvider);
      if (state.status == ChunkyExecutionStatus.paused ||
          state.status == ChunkyExecutionStatus.idle ||
          state.status == ChunkyExecutionStatus.awaitingResume ||
          state.status == ChunkyExecutionStatus.completed ||
          state.status == ChunkyExecutionStatus.error) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }

  Future<void> _runScheduledBackupWithRetry({
    required ScheduleItem schedule,
    required String serverPath,
    required BackupConfigSettings backupConfig,
  }) async {
    final statusNotifier = _ref.read(autoBackupStatusProvider.notifier);
    if (_automaticBackupInProgress) {
      const message = 'Já existe um backup automático em progresso.';
      statusNotifier.markFailure(message);
      await _logAutomaticBackup(
        schedule: schedule,
        attempt: 0,
        resultStatus: 'blocked',
        message: message,
      );
      throw StateError(message);
    }

    _automaticBackupInProgress = true;
    statusNotifier.setRunning(true);

    try {
      for (var attempt = 1; attempt <= _maxBackupAttempts; attempt++) {
        try {
          await _executeBackupAttempt(
            schedule: schedule,
            serverPath: serverPath,
            backupConfig: backupConfig,
          );
          await _logAutomaticBackup(
            schedule: schedule,
            attempt: attempt,
            resultStatus: 'success',
            message: 'Backup automático concluído.',
          );
          statusNotifier.clearFailure();
          return;
        } catch (error) {
          final message = _normalizeError(error);
          final isLastAttempt = attempt >= _maxBackupAttempts;
          await _logAutomaticBackup(
            schedule: schedule,
            attempt: attempt,
            resultStatus: isLastAttempt ? 'error' : 'retry_error',
            message: message,
          );
          if (isLastAttempt) {
            statusNotifier.markFailure(
              'Falha no backup automático (${schedule.title.trim().isEmpty ? 'agendamento' : schedule.title}).',
            );
            throw StateError(message);
          }
          await _waitRetryInterval();
        }
      }
    } finally {
      _automaticBackupInProgress = false;
      statusNotifier.setRunning(false);
    }
  }

  Future<void> _executeBackupAttempt({
    required ScheduleItem schedule,
    required String serverPath,
    required BackupConfigSettings backupConfig,
  }) async {
    final kind = schedule.backupKind;
    if (kind == ScheduleBackupKind.app) {
      await _ref.read(appBackupsProvider.notifier).createAutomaticBackup();
      return;
    }

    if (!await _isServerBackupAllowed(backupConfig)) {
      throw StateError(
        'Backup de servidor indisponível. Verifique Config > Backup.',
      );
    }

    final service = _ref.read(backupServiceProvider);
    if (kind == ScheduleBackupKind.selective &&
        schedule.selectiveRootEntries.isEmpty) {
      throw StateError(
        'Backup seletivo automático exige itens raiz configurados.',
      );
    }

    await service.createBackup(
      serverPath: serverPath,
      config: backupConfig,
      trigger: BackupTriggerType.schedule,
      kind: kind.backupContentKind,
      selectiveRootEntries: schedule.selectiveRootEntries,
      selectiveSummary: schedule.selectiveRootEntries.join(', '),
    );
  }

  Future<bool> _isServerBackupAllowed(BackupConfigSettings config) async {
    if (!config.backupsEnabled) return false;
    final path = config.backupPath.trim();
    if (path.isEmpty) return false;
    return Directory(path).existsSync();
  }

  Future<void> _waitRetryInterval() async {
    final seconds = await _resolveRetryIntervalSeconds();
    await Future<void>.delayed(Duration(seconds: seconds));
  }

  Future<int> _resolveRetryIntervalSeconds() async {
    final raw = await AppDatabase.instance.getSetting(
      'auto_backup_retry_interval_seconds',
    );
    final value =
        int.tryParse((raw ?? '').trim()) ?? _defaultRetryIntervalSeconds;
    if (value < 1) {
      return _defaultRetryIntervalSeconds;
    }
    return value;
  }

  Future<void> _logAutomaticBackup({
    required ScheduleItem schedule,
    required int attempt,
    required String resultStatus,
    required String message,
  }) async {
    await _ref
        .read(automaticBackupHistoryRepositoryProvider)
        .logAttempt(
          scheduleId: schedule.id,
          scheduleTitle: schedule.title,
          scheduleAction: schedule.action.storageValue,
          backupKind: schedule.backupKind.storageValue,
          attemptNumber: attempt,
          resultStatus: resultStatus,
          message: message,
        );
  }

  Future<void> _sendSaveAllIfNeeded(ScheduleBackupKind kind) async {
    if (!kind.usesWorldState) {
      return;
    }
    final runtime = _ref.read(serverRuntimeProvider);
    if (runtime.lifecycle != ServerLifecycleState.online) {
      return;
    }
    final runtimeNotifier = _ref.read(serverRuntimeProvider.notifier);
    await runtimeNotifier.sendCommand(_commands.saveAll(flush: true));
  }

  String _normalizeError(Object error) {
    return error.toString().replaceFirst('Bad state: ', '').trim();
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
    await runtimeNotifier.sendCommand(
      _commands.say(message, prefix: '[SERVER 🤖]'),
    );
  }

  String _minuteKey(DateTime dt) {
    return '${dt.year}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}${dt.hour.toString().padLeft(2, '0')}${dt.minute.toString().padLeft(2, '0')}';
  }
}
