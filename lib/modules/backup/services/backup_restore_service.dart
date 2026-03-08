import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../../config/services/server_properties_service.dart';
import '../models/backup_config_settings.dart';
import '../models/backup_entry.dart';
import 'backup_service.dart';

class BackupRestoreService {
  BackupRestoreService({
    BackupService? backupService,
    ServerPropertiesService? propertiesService,
  }) : _backupService = backupService ?? BackupService(),
       _propertiesService = propertiesService ?? ServerPropertiesService();

  final BackupService _backupService;
  final ServerPropertiesService _propertiesService;

  Future<void> restoreWorld({
    required String backupZipPath,
    required String serverPath,
    required BackupConfigSettings backupConfig,
    required bool isServerOffline,
    required int activePlayers,
  }) async {
    _assertRestoreAllowed(
      isServerOffline: isServerOffline,
      activePlayers: activePlayers,
    );

    final zipFile = File(backupZipPath);
    if (!await zipFile.exists()) {
      throw StateError('Arquivo de backup não encontrado para restauração.');
    }

    await _backupService.createBackup(
      serverPath: serverPath,
      config: backupConfig,
      trigger: BackupTriggerType.manual,
      kind: BackupContentKind.full,
    );

    final worldName = await _resolveWorldName(serverPath);
    final tempDir = await Directory.systemTemp.createTemp('restore_world_');
    try {
      await _extractZipSafely(zipFile, tempDir);
      final extractedWorld = await _locateWorldDirectory(tempDir, worldName);
      if (extractedWorld == null || !await extractedWorld.exists()) {
        throw StateError(
          'Não foi possível localizar a pasta do mundo "$worldName" no backup.',
        );
      }

      final targetWorldDir = Directory(p.join(serverPath, worldName));
      if (await targetWorldDir.exists()) {
        await targetWorldDir.delete(recursive: true);
      }
      await _copyDirectory(extractedWorld, targetWorldDir);
    } finally {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  }

  Future<void> restoreFull({
    required String backupZipPath,
    required String serverPath,
    required BackupConfigSettings backupConfig,
    required bool isServerOffline,
    required int activePlayers,
  }) async {
    _assertRestoreAllowed(
      isServerOffline: isServerOffline,
      activePlayers: activePlayers,
    );

    final zipFile = File(backupZipPath);
    if (!await zipFile.exists()) {
      throw StateError('Arquivo de backup não encontrado para restauração.');
    }

    await _backupService.createBackup(
      serverPath: serverPath,
      config: backupConfig,
      trigger: BackupTriggerType.manual,
      kind: BackupContentKind.full,
    );

    final serverDir = Directory(serverPath);
    if (!await serverDir.exists()) {
      throw StateError('Pasta do servidor não encontrada para restauração.');
    }

    final tempDir = await Directory.systemTemp.createTemp('restore_full_');
    try {
      await _extractZipSafely(zipFile, tempDir);

      final children = await serverDir.list(followLinks: false).toList();
      for (final entity in children) {
        await entity.delete(recursive: true);
      }

      final extracted = await tempDir.list(followLinks: false).toList();
      for (final entity in extracted) {
        final targetPath = p.join(serverPath, p.basename(entity.path));
        if (entity is File) {
          await entity.copy(targetPath);
        } else if (entity is Directory) {
          await _copyDirectory(entity, Directory(targetPath));
        }
      }
    } finally {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  }

  void _assertRestoreAllowed({
    required bool isServerOffline,
    required int activePlayers,
  }) {
    if (!isServerOffline) {
      throw StateError('Restauração exige servidor OFFLINE.');
    }
    if (activePlayers > 0) {
      throw StateError(
        'Existem players ativos. Pare o servidor corretamente antes de restaurar.',
      );
    }
  }

  Future<String> _resolveWorldName(String serverPath) async {
    final settings = await _propertiesService.loadFromFile(serverPath);
    final name = settings?.serverName.trim() ?? '';
    return name.isEmpty ? 'world' : name;
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

  Future<Directory?> _locateWorldDirectory(
    Directory extractedRoot,
    String worldName,
  ) async {
    final direct = Directory(p.join(extractedRoot.path, worldName));
    if (await direct.exists()) {
      return direct;
    }

    await for (final entity in extractedRoot.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is Directory &&
          p.basename(entity.path).toLowerCase() == worldName.toLowerCase()) {
        return entity;
      }
    }
    return null;
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
}
