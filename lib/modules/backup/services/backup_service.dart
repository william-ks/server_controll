import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../models/backup_config_settings.dart';
import '../models/backup_entry.dart';

enum BackupTriggerType { manual, schedule, chunk }

class BackupTaskController {
  bool _cancelled = false;
  String? _targetFilePath;

  bool get isCancelled => _cancelled;
  String? get targetFilePath => _targetFilePath;

  void attachTarget(String path) {
    _targetFilePath = path;
  }

  Future<void> cancel() async {
    _cancelled = true;
    final target = _targetFilePath;
    if (target == null || target.isEmpty) return;
    final file = File(target);
    if (await file.exists()) {
      await file.delete();
    }
  }
}

class BackupService {
  Future<BackupEntry> createBackup({
    required String serverPath,
    required BackupConfigSettings config,
    required BackupTriggerType trigger,
    BackupTaskController? controller,
  }) async {
    final sourceDir = Directory(serverPath);
    if (!await sourceDir.exists()) {
      throw StateError('Pasta do servidor não encontrada.');
    }

    if (!config.backupsEnabled) {
      throw StateError('Backups estão desativados em Config > Backup.');
    }

    final backupDirPath = config.backupPath.trim();
    if (backupDirPath.isEmpty) {
      throw StateError('Pasta de backup não configurada.');
    }

    final backupDir = Directory(backupDirPath);
    if (!await backupDir.exists()) {
      throw StateError('Pasta de backup não encontrada.');
    }

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final prefix = switch (trigger) {
      BackupTriggerType.schedule => 'Agendamento',
      BackupTriggerType.chunk => 'Chunk',
      BackupTriggerType.manual => 'Manual',
    };
    final backupName = '${prefix}_$timestamp.zip';
    final backupFilePath = p.join(backupDir.path, backupName);
    controller?.attachTarget(backupFilePath);

    final encoder = ZipFileEncoder();
    encoder.create(backupFilePath);
    encoder.addDirectory(sourceDir, includeDirName: false);
    encoder.close();

    if (controller?.isCancelled == true) {
      final cancelledFile = File(backupFilePath);
      if (await cancelledFile.exists()) {
        await cancelledFile.delete();
      }
      throw StateError('Backup cancelado pelo usuário.');
    }

    await enforceRetention(config);

    final created = File(backupFilePath);
    final stat = await created.stat();
    return BackupEntry(
      name: p.basename(created.path),
      path: created.path,
      sizeBytes: stat.size,
      modifiedAt: stat.modified,
      kind: _kindFromName(p.basename(created.path)),
    );
  }

  Future<List<BackupEntry>> listBackups(BackupConfigSettings config) async {
    final backupDirPath = config.backupPath.trim();
    if (backupDirPath.isEmpty) return const [];

    final backupDir = Directory(backupDirPath);
    if (!await backupDir.exists()) return const [];

    final entries = <BackupEntry>[];
    await for (final entity in backupDir.list(followLinks: false)) {
      if (entity is! File || !entity.path.toLowerCase().endsWith('.zip')) {
        continue;
      }
      final stat = await entity.stat();
      entries.add(
        BackupEntry(
          name: p.basename(entity.path),
          path: entity.path,
          sizeBytes: stat.size,
          modifiedAt: stat.modified,
          kind: _kindFromName(p.basename(entity.path)),
        ),
      );
    }

    entries.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return entries;
  }

  Future<void> deleteBackup(String backupFilePath) async {
    final file = File(backupFilePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> enforceRetention(BackupConfigSettings config) async {
    final maxBackups = int.tryParse(config.maxBackups.trim()) ?? 1;
    if (maxBackups < 1) {
      return;
    }

    final backups = await listBackups(config);
    if (backups.length <= maxBackups) {
      return;
    }

    for (var index = maxBackups; index < backups.length; index++) {
      await deleteBackup(backups[index].path);
    }
  }

  BackupKind _kindFromName(String name) {
    if (name.startsWith('Manual_')) return BackupKind.manual;
    if (name.startsWith('Agendamento_')) return BackupKind.schedule;
    if (name.startsWith('Chunk_')) return BackupKind.chunk;
    return BackupKind.unknown;
  }
}
