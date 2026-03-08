import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../database/app_database.dart';
import '../models/app_backup_entry.dart';

class AppBackupService {
  static const _metadataFileName = 'app_backup_metadata.json';

  Future<AppBackupEntry> createAppBackup({required bool automatic}) async {
    final appDir = await getApplicationSupportDirectory();
    final dbPath = await AppDatabase.instance.resolveDatabasePath();
    final dbFile = File(dbPath);
    if (!await dbFile.exists()) {
      throw StateError('Banco de dados do app não encontrado para backup.');
    }

    final backupDir = await _resolveAppBackupDir();
    await backupDir.create(recursive: true);

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final triggerTag = automatic ? 'schedule' : 'manual';
    final backupName = '${timestamp}__${triggerTag}__app.zip';
    final backupPath = p.join(backupDir.path, backupName);

    final staging = await Directory.systemTemp.createTemp('app_backup_');
    try {
      await dbFile.copy(p.join(staging.path, 'minecontrol.db'));
      await _copyDirectoryIfExists(
        Directory(p.join(appDir.path, 'whitelist_icons')),
        Directory(p.join(staging.path, 'whitelist_icons')),
      );
      await _copyDirectoryIfExists(
        Directory(p.join(appDir.path, 'maintenance')),
        Directory(p.join(staging.path, 'maintenance')),
      );

      await _writeMetadata(
        filePath: p.join(staging.path, _metadataFileName),
        automatic: automatic,
      );

      final encoder = ZipFileEncoder();
      encoder.create(backupPath);
      encoder.addDirectory(staging, includeDirName: false);
      encoder.close();
    } finally {
      if (await staging.exists()) {
        await staging.delete(recursive: true);
      }
    }

    return _toEntry(File(backupPath));
  }

  Future<List<AppBackupEntry>> listBackups() async {
    final dir = await _resolveAppBackupDir();
    if (!await dir.exists()) return const [];

    final entries = <AppBackupEntry>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File || !entity.path.toLowerCase().endsWith('.zip')) {
        continue;
      }
      entries.add(await _toEntry(entity));
    }
    entries.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return entries;
  }

  Future<void> deleteBackup(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<AppBackupEntry> importAppBackup(String sourceZipPath) async {
    final source = File(sourceZipPath);
    if (!await source.exists()) {
      throw StateError('Arquivo selecionado não encontrado para importação.');
    }
    await _validateZipStructure(source);

    final backupDir = await _resolveAppBackupDir();
    await backupDir.create(recursive: true);

    final targetPath = await _resolveImportTargetPath(
      backupDir: backupDir,
      sourcePath: source.path,
    );
    final target = File(targetPath);
    final normalizedSource = p.normalize(source.path);
    final normalizedTarget = p.normalize(target.path);
    if (normalizedSource == normalizedTarget) {
      return _toEntry(target);
    }

    await source.copy(target.path);
    return _toEntry(target);
  }

  Future<String> exportAppBackup({
    required String backupPath,
    required String destinationPath,
  }) async {
    final source = File(backupPath);
    if (!await source.exists()) {
      throw StateError('Backup do app não encontrado para exportação.');
    }
    final destination = File(destinationPath);
    await destination.parent.create(recursive: true);
    await source.copy(destination.path);
    return destination.path;
  }

  Future<void> restoreAppBackup(String backupPath) async {
    final backupFile = File(backupPath);
    if (!await backupFile.exists()) {
      throw StateError('Backup do app não encontrado para restauração.');
    }

    final appDir = await getApplicationSupportDirectory();
    final dbPath = await AppDatabase.instance.resolveDatabasePath();
    final tempDir = await Directory.systemTemp.createTemp('app_restore_');

    try {
      await _extractZipSafely(backupFile, tempDir);
      await _validateExtractedBackup(tempDir);

      final extractedDb = File(p.join(tempDir.path, 'minecontrol.db'));
      await AppDatabase.instance.closeConnection();
      final targetDb = File(dbPath);
      if (await targetDb.exists()) {
        await targetDb.delete();
      }
      await extractedDb.copy(targetDb.path);

      await _restoreDirectorySnapshot(
        source: Directory(p.join(tempDir.path, 'whitelist_icons')),
        target: Directory(p.join(appDir.path, 'whitelist_icons')),
      );
      await _restoreDirectorySnapshot(
        source: Directory(p.join(tempDir.path, 'maintenance')),
        target: Directory(p.join(appDir.path, 'maintenance')),
      );

      await AppDatabase.instance.database;
    } finally {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  }

  Future<Directory> _resolveAppBackupDir() async {
    final configured = await AppDatabase.instance.getSetting('app_backup_path');
    if (configured != null && configured.trim().isNotEmpty) {
      return Directory(configured.trim());
    }
    final appDir = await getApplicationSupportDirectory();
    return Directory(p.join(appDir.path, 'app_backups'));
  }

  Future<AppBackupEntry> _toEntry(File file) async {
    final stat = await file.stat();
    return AppBackupEntry(
      name: p.basename(file.path),
      path: file.path,
      sizeBytes: stat.size,
      modifiedAt: stat.modified,
    );
  }

  Future<void> _copyDirectoryIfExists(
    Directory source,
    Directory target,
  ) async {
    if (!await source.exists()) return;
    await _copyDirectory(source, target);
  }

  Future<void> _copyDirectory(Directory source, Directory target) async {
    if (!await target.exists()) {
      await target.create(recursive: true);
    }
    await for (final entity in source.list(followLinks: false)) {
      final name = p.basename(entity.path);
      final targetPath = p.join(target.path, name);
      if (entity is File) {
        await entity.copy(targetPath);
      } else if (entity is Directory) {
        await _copyDirectory(entity, Directory(targetPath));
      }
    }
  }

  Future<void> _restoreDirectorySnapshot({
    required Directory source,
    required Directory target,
  }) async {
    if (await target.exists()) {
      await target.delete(recursive: true);
    }
    if (!await source.exists()) {
      return;
    }
    await _copyDirectory(source, target);
  }

  Future<void> _extractZipSafely(File zipFile, Directory destination) async {
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    final destinationRoot = p.normalize(destination.path);

    for (final item in archive) {
      final normalizedTarget = p.normalize(
        p.join(
          destinationRoot,
          item.name.replaceAll('/', Platform.pathSeparator),
        ),
      );
      if (!p.isWithin(destinationRoot, normalizedTarget) &&
          normalizedTarget != destinationRoot) {
        throw StateError('O backup contém caminho inválido.');
      }

      if (item.isFile) {
        final file = File(normalizedTarget);
        await file.parent.create(recursive: true);
        final content = item.content as List<int>;
        await file.writeAsBytes(content);
      } else {
        await Directory(normalizedTarget).create(recursive: true);
      }
    }
  }

  Future<void> _writeMetadata({
    required String filePath,
    required bool automatic,
  }) async {
    final metadata = File(filePath);
    final appVersion = await AppDatabase.instance.getSetting('app_version');
    await metadata.writeAsString(
      jsonEncode({
        'created_at': DateTime.now().toIso8601String(),
        'schema_version': AppDatabase.schemaVersion,
        'app_version': (appVersion ?? '').trim().isEmpty
            ? 'unknown'
            : appVersion!.trim(),
        'backup_format_version': 1,
        'automatic': automatic,
      }),
    );
  }

  Future<void> _validateZipStructure(File zipFile) async {
    final tempDir = await Directory.systemTemp.createTemp(
      'app_import_validate_',
    );
    try {
      await _extractZipSafely(zipFile, tempDir);
      await _validateExtractedBackup(tempDir);
    } finally {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  }

  Future<void> _validateExtractedBackup(Directory extractedRoot) async {
    final dbFile = File(p.join(extractedRoot.path, 'minecontrol.db'));
    if (!await dbFile.exists()) {
      throw StateError(
        'Backup inválido: arquivo minecontrol.db não encontrado.',
      );
    }

    final metadataFile = File(p.join(extractedRoot.path, _metadataFileName));
    if (!await metadataFile.exists()) {
      throw StateError('Backup inválido: metadados não encontrados.');
    }

    final metadataRaw = await metadataFile.readAsString();
    final decoded = jsonDecode(metadataRaw);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Backup inválido: metadados corrompidos.');
    }
    final schema = decoded['schema_version'];
    if (schema is! int || schema <= 0) {
      throw StateError('Backup inválido: schema_version ausente.');
    }
  }

  Future<String> _resolveImportTargetPath({
    required Directory backupDir,
    required String sourcePath,
  }) async {
    final baseName = p.basename(sourcePath);
    var targetPath = p.join(backupDir.path, baseName);
    if (!await File(targetPath).exists()) {
      return targetPath;
    }

    final stem = p.basenameWithoutExtension(baseName);
    final ext = p.extension(baseName);
    var attempt = 1;
    while (true) {
      final candidate = p.join(
        backupDir.path,
        '${stem}__imported_$attempt$ext',
      );
      if (!await File(candidate).exists()) {
        return candidate;
      }
      attempt++;
    }
  }
}
