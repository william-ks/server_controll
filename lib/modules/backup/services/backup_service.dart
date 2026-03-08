import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../database/app_database.dart';
import '../../config/services/server_properties_service.dart';
import '../models/backup_capacity_status.dart';
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
  BackupService({AppDatabase? db}) : _db = db ?? AppDatabase.instance;

  static final _namePattern = RegExp(
    r'^(\d{8}_\d{6})__([a-z]+)__([a-z]+)\.zip$',
    caseSensitive: false,
  );

  final ServerPropertiesService _propertiesService = ServerPropertiesService();
  final AppDatabase _db;

  Future<BackupEntry> createBackup({
    required String serverPath,
    required BackupConfigSettings config,
    required BackupTriggerType trigger,
    BackupContentKind kind = BackupContentKind.full,
    List<String> selectiveRootEntries = const [],
    String? selectiveSummary,
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
    final backupName =
        '${timestamp}__${_originTag(trigger)}__${_contentTag(kind)}.zip';
    final backupFilePath = p.join(backupDir.path, backupName);
    controller?.attachTarget(backupFilePath);

    switch (kind) {
      case BackupContentKind.full:
        await _zipDirectory(
          backupFilePath: backupFilePath,
          sourceDir: sourceDir,
          includeRootDirName: false,
        );
      case BackupContentKind.world:
        final worldName = await _resolveWorldName(serverPath);
        final worldDir = Directory(p.join(serverPath, worldName));
        if (!await worldDir.exists()) {
          throw StateError(
            'Pasta do mundo "$worldName" não encontrada na raiz do servidor.',
          );
        }
        await _zipDirectory(
          backupFilePath: backupFilePath,
          sourceDir: worldDir,
          includeRootDirName: true,
        );
      case BackupContentKind.selective:
        if (selectiveRootEntries.isEmpty) {
          throw StateError(
            'Selecione ao menos um item raiz para backup seletivo.',
          );
        }
        await _zipSelectiveRoots(
          backupFilePath: backupFilePath,
          serverRoot: sourceDir,
          selectedRoots: selectiveRootEntries,
        );
      case BackupContentKind.app:
        throw StateError(
          'Backup do app é tratado por serviço dedicado de backup do aplicativo.',
        );
      case BackupContentKind.unknown:
        throw StateError('Tipo de backup inválido.');
    }

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
    final createdName = p.basename(created.path);
    if (kind == BackupContentKind.selective) {
      final summary = selectiveSummary?.trim().isNotEmpty == true
          ? selectiveSummary!.trim()
          : selectiveRootEntries.join(', ');
      await _saveMetadata(
        backupName: createdName,
        trigger: trigger,
        contentKind: kind,
        summary: summary,
      );
    }
    final meta = _extractMetadataFromName(
      name: createdName,
      modifiedAt: stat.modified,
    );
    return BackupEntry(
      name: createdName,
      path: created.path,
      sizeBytes: stat.size,
      modifiedAt: stat.modified,
      origin: meta.origin,
      contentKind: meta.contentKind,
      timestamp: meta.timestamp,
      description: kind == BackupContentKind.selective
          ? (selectiveSummary?.trim().isNotEmpty == true
                ? selectiveSummary!.trim()
                : selectiveRootEntries.join(', '))
          : null,
    );
  }

  Future<List<BackupEntry>> listBackups(BackupConfigSettings config) async {
    final backupDirPath = config.backupPath.trim();
    if (backupDirPath.isEmpty) return const [];

    final backupDir = Directory(backupDirPath);
    if (!await backupDir.exists()) return const [];
    final metadataByName = await _loadMetadataByBackupName();

    final entries = <BackupEntry>[];
    await for (final entity in backupDir.list(followLinks: false)) {
      if (entity is! File || !entity.path.toLowerCase().endsWith('.zip')) {
        continue;
      }
      final stat = await entity.stat();
      final name = p.basename(entity.path);
      final meta = _extractMetadataFromName(
        name: name,
        modifiedAt: stat.modified,
      );
      entries.add(
        BackupEntry(
          name: name,
          path: entity.path,
          sizeBytes: stat.size,
          modifiedAt: stat.modified,
          origin: meta.origin,
          contentKind: meta.contentKind,
          timestamp: meta.timestamp,
          description: metadataByName[name],
        ),
      );
    }

    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return entries;
  }

  Future<void> deleteBackup(String backupFilePath) async {
    final file = File(backupFilePath);
    final fileName = p.basename(backupFilePath);
    if (await file.exists()) {
      await file.delete();
    }
    final db = await _db.database;
    await db.delete(
      'backup_history_metadata',
      where: 'backup_name = ?',
      whereArgs: [fileName],
    );
  }

  Future<void> enforceRetention(BackupConfigSettings config) async {
    final limitBytes = _limitBytesFromConfig(config.retentionMaxGb);
    if (limitBytes <= 0) {
      return;
    }

    final backups = await listBackups(config);
    final usedBytes = backups.fold<int>(0, (sum, item) => sum + item.sizeBytes);
    if (usedBytes <= limitBytes) {
      return;
    }

    if (!config.autoCleanupEnabled) {
      return;
    }

    final sortedOldestFirst = [...backups]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    var currentSize = usedBytes;
    for (final backup in sortedOldestFirst) {
      if (currentSize <= limitBytes) {
        break;
      }
      await deleteBackup(backup.path);
      currentSize -= backup.sizeBytes;
    }
  }

  Future<BackupCapacityStatus> evaluateCapacity(
    BackupConfigSettings config,
  ) async {
    final usedBytes = (await listBackups(
      config,
    )).fold<int>(0, (sum, item) => sum + item.sizeBytes);
    final limitBytes = _limitBytesFromConfig(config.retentionMaxGb);
    if (limitBytes <= 0) {
      return BackupCapacityStatus(
        level: BackupCapacityLevel.normal,
        usedBytes: usedBytes,
        limitBytes: 0,
        usedPercent: 0,
      );
    }

    final usedPercent = (usedBytes / limitBytes) * 100;
    final warnPercent = config.capacityWarnThresholdPercent.clamp(1, 99);
    final level = usedPercent > 100
        ? BackupCapacityLevel.exceeded
        : (usedPercent == 100
              ? BackupCapacityLevel.reached
              : (usedPercent >= warnPercent
                    ? BackupCapacityLevel.warning
                    : BackupCapacityLevel.normal));

    return BackupCapacityStatus(
      level: level,
      usedBytes: usedBytes,
      limitBytes: limitBytes,
      usedPercent: usedPercent,
    );
  }

  Future<String> _resolveWorldName(String serverPath) async {
    final settings = await _propertiesService.loadFromFile(serverPath);
    final name = settings?.serverName.trim() ?? '';
    if (name.isEmpty) {
      return 'world';
    }
    return name;
  }

  Future<void> _zipDirectory({
    required String backupFilePath,
    required Directory sourceDir,
    required bool includeRootDirName,
  }) async {
    final encoder = ZipFileEncoder();
    encoder.create(backupFilePath);
    encoder.addDirectory(sourceDir, includeDirName: includeRootDirName);
    encoder.close();
  }

  Future<void> _zipSelectiveRoots({
    required String backupFilePath,
    required Directory serverRoot,
    required List<String> selectedRoots,
  }) async {
    final encoder = ZipFileEncoder();
    encoder.create(backupFilePath);

    final normalizedRoot = p.normalize(serverRoot.path);
    for (final entry in selectedRoots) {
      final relativeName = entry.trim();
      if (relativeName.isEmpty) continue;
      if (relativeName.contains('/') || relativeName.contains(r'\')) {
        throw StateError(
          'Seleção inválida: apenas entradas de primeiro nível são permitidas.',
        );
      }

      final targetPath = p.normalize(p.join(normalizedRoot, relativeName));
      if (!p.isWithin(normalizedRoot, targetPath) &&
          targetPath != normalizedRoot) {
        throw StateError('Seleção inválida fora da raiz do servidor.');
      }

      final fileType = FileSystemEntity.typeSync(targetPath);
      if (fileType == FileSystemEntityType.notFound) {
        throw StateError('Entrada "$relativeName" não encontrada na raiz.');
      }

      if (fileType == FileSystemEntityType.directory) {
        encoder.addDirectory(
          Directory(targetPath),
          includeDirName: true,
          level: 6,
        );
      } else if (fileType == FileSystemEntityType.file) {
        encoder.addFile(File(targetPath), relativeName);
      }
    }

    encoder.close();
  }

  _BackupNameMetadata _extractMetadataFromName({
    required String name,
    required DateTime modifiedAt,
  }) {
    final match = _namePattern.firstMatch(name);
    if (match != null) {
      final timestampRaw = match.group(1)!;
      final originRaw = match.group(2)!.toLowerCase();
      final kindRaw = match.group(3)!.toLowerCase();
      return _BackupNameMetadata(
        origin: _originFromTag(originRaw),
        contentKind: _contentKindFromTag(kindRaw),
        timestamp:
            DateTime.tryParse(
              '${timestampRaw.substring(0, 4)}-${timestampRaw.substring(4, 6)}-${timestampRaw.substring(6, 8)} ${timestampRaw.substring(9, 11)}:${timestampRaw.substring(11, 13)}:${timestampRaw.substring(13, 15)}',
            ) ??
            modifiedAt,
      );
    }

    if (name.startsWith('Manual_')) {
      return _BackupNameMetadata(
        origin: BackupOriginKind.manual,
        contentKind: BackupContentKind.full,
        timestamp: modifiedAt,
      );
    }
    if (name.startsWith('Agendamento_')) {
      return _BackupNameMetadata(
        origin: BackupOriginKind.schedule,
        contentKind: BackupContentKind.full,
        timestamp: modifiedAt,
      );
    }
    if (name.startsWith('Chunk_')) {
      return _BackupNameMetadata(
        origin: BackupOriginKind.chunk,
        contentKind: BackupContentKind.full,
        timestamp: modifiedAt,
      );
    }

    return _BackupNameMetadata(
      origin: BackupOriginKind.unknown,
      contentKind: BackupContentKind.unknown,
      timestamp: modifiedAt,
    );
  }

  String _originTag(BackupTriggerType trigger) {
    return switch (trigger) {
      BackupTriggerType.manual => 'manual',
      BackupTriggerType.schedule => 'schedule',
      BackupTriggerType.chunk => 'chunk',
    };
  }

  String _contentTag(BackupContentKind kind) {
    return switch (kind) {
      BackupContentKind.full => 'full',
      BackupContentKind.world => 'world',
      BackupContentKind.selective => 'selective',
      BackupContentKind.app => 'app',
      BackupContentKind.unknown => 'unknown',
    };
  }

  BackupOriginKind _originFromTag(String raw) {
    return switch (raw) {
      'manual' => BackupOriginKind.manual,
      'schedule' => BackupOriginKind.schedule,
      'chunk' => BackupOriginKind.chunk,
      _ => BackupOriginKind.unknown,
    };
  }

  BackupContentKind _contentKindFromTag(String raw) {
    return switch (raw) {
      'full' => BackupContentKind.full,
      'world' => BackupContentKind.world,
      'selective' => BackupContentKind.selective,
      'app' => BackupContentKind.app,
      _ => BackupContentKind.unknown,
    };
  }

  int _limitBytesFromConfig(String rawValue) {
    final parsed = double.tryParse(rawValue.replaceAll(',', '.')) ?? 0;
    if (parsed <= 0) {
      return 0;
    }
    return (parsed * 1024 * 1024 * 1024).floor();
  }

  Future<Map<String, String>> _loadMetadataByBackupName() async {
    final db = await _db.database;
    final rows = await db.query(
      'backup_history_metadata',
      columns: ['backup_name', 'summary_text'],
    );
    final map = <String, String>{};
    for (final row in rows) {
      final name = (row['backup_name'] as String?)?.trim() ?? '';
      if (name.isEmpty) {
        continue;
      }
      final summary = (row['summary_text'] as String?)?.trim() ?? '';
      if (summary.isNotEmpty) {
        map[name] = summary;
      }
    }
    return map;
  }

  Future<void> _saveMetadata({
    required String backupName,
    required BackupTriggerType trigger,
    required BackupContentKind contentKind,
    required String summary,
  }) async {
    final db = await _db.database;
    await db.insert('backup_history_metadata', {
      'backup_name': backupName,
      'trigger': _originTag(trigger),
      'content_kind': _contentTag(contentKind),
      'summary_text': summary,
      'created_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}

class _BackupNameMetadata {
  const _BackupNameMetadata({
    required this.origin,
    required this.contentKind,
    required this.timestamp,
  });

  final BackupOriginKind origin;
  final BackupContentKind contentKind;
  final DateTime timestamp;
}
