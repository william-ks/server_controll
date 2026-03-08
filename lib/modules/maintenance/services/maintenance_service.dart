import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../database/app_database.dart';
import '../../config/services/server_properties_service.dart';
import '../../server/services/minecraft_command_provider.dart';
import '../models/maintenance_defaults.dart';
import '../models/maintenance_mode.dart';
import '../models/maintenance_snapshot.dart';

typedef SendCommandFn = Future<void> Function(String command);

class MaintenanceService {
  static const _commands = MinecraftCommandProvider.vanilla;
  static const List<String> _iconCandidates = [
    'server-icon.png',
    'server-icon.jpg',
    'server-icon.jpeg',
    'server-icon.webp',
  ];

  MaintenanceService({AppDatabase? db, ServerPropertiesService? properties})
    : _db = db ?? AppDatabase.instance,
      _propertiesService = properties ?? ServerPropertiesService();

  final AppDatabase _db;
  final ServerPropertiesService _propertiesService;

  Future<MaintenanceSnapshot> loadSnapshot() async {
    final db = await _db.database;
    final rows = await db.query('maintenance_state', where: 'id = 1', limit: 1);
    if (rows.isEmpty) {
      return MaintenanceSnapshot.inactive();
    }
    final row = rows.first;
    return MaintenanceSnapshot(
      isActive: (row['is_active'] as int? ?? 0) == 1,
      mode: MaintenanceModeX.fromStorage((row['mode'] as String?) ?? 'total'),
      startsAt: DateTime.tryParse((row['starts_at'] as String?) ?? ''),
      endsAt: DateTime.tryParse((row['ends_at'] as String?) ?? ''),
      countdownSeconds: row['countdown_seconds'] as int? ?? 0,
      motdBefore: row['motd_before'] as String?,
      motdDuring: row['motd_during'] as String?,
      iconBeforePath: row['icon_before_path'] as String?,
      iconDuringPath: row['icon_during_path'] as String?,
    );
  }

  Future<MaintenanceDefaults> loadDefaults() async {
    return MaintenanceDefaults.fromDatabase(_db);
  }

  Future<void> saveDefaults(MaintenanceDefaults defaults) async {
    await _db.setSetting(
      'maintenance_default_mode',
      defaults.defaultMode.storageValue,
    );
    await _db.setSetting(
      'maintenance_countdown_default',
      '${defaults.defaultCountdownSeconds}',
    );
    await _db.setSetting('maintenance_motd_total', defaults.motdTotal);
    await _db.setSetting('maintenance_motd_admin', defaults.motdAdminsOnly);
    await _db.setSetting('maintenance_icon_path', defaults.maintenanceIconPath);
    await _db.setSetting(
      'maintenance_admin_nicknames',
      defaults.adminNicknames.trim(),
    );
  }

  Future<void> saveScheduledState({
    required MaintenanceMode mode,
    required DateTime startsAt,
    required int countdownSeconds,
  }) async {
    await _upsertState({
      'id': 1,
      'is_active': 0,
      'mode': mode.storageValue,
      'starts_at': startsAt.toIso8601String(),
      'ends_at': null,
      'countdown_seconds': countdownSeconds,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<MaintenanceSnapshot> activate({
    required MaintenanceMode mode,
    required String serverPath,
  }) async {
    final now = DateTime.now();
    final defaults = await loadDefaults();
    final maintenanceIconPath = await _resolveMaintenanceIconPath(
      defaults.maintenanceIconPath,
    );
    final motdDuring = mode == MaintenanceMode.total
        ? defaults.motdTotal
        : defaults.motdAdminsOnly;

    String? motdBefore;
    String? iconBeforePath;
    String? iconDuringPath;

    if (serverPath.trim().isNotEmpty) {
      final loaded = await _propertiesService.loadFromFile(serverPath.trim());
      motdBefore = loaded?.description;
      if (loaded != null) {
        await _propertiesService.saveToFile(
          serverPath: serverPath.trim(),
          settings: loaded.copyWith(description: motdDuring),
        );
      }

      iconBeforePath = await _backupCurrentServerIcon(serverPath.trim());
      iconDuringPath = await _applyMaintenanceIcon(
        serverPath.trim(),
        maintenanceIconPath,
      );
    }

    await _upsertState({
      'id': 1,
      'is_active': 1,
      'mode': mode.storageValue,
      'starts_at': now.toIso8601String(),
      'ends_at': null,
      'countdown_seconds': 0,
      'motd_before': motdBefore,
      'motd_during': motdDuring,
      'icon_before_path': iconBeforePath,
      'icon_during_path': iconDuringPath,
      'updated_at': now.toIso8601String(),
    });

    return loadSnapshot();
  }

  Future<MaintenanceSnapshot> deactivate({required String serverPath}) async {
    final snapshot = await loadSnapshot();
    if (!snapshot.isActive) {
      await _upsertState({
        'id': 1,
        'is_active': 0,
        'mode': snapshot.mode.storageValue,
        'starts_at': null,
        'ends_at': DateTime.now().toIso8601String(),
        'countdown_seconds': 0,
        'updated_at': DateTime.now().toIso8601String(),
      });
      return loadSnapshot();
    }

    final trimmedServerPath = serverPath.trim();
    if (trimmedServerPath.isNotEmpty) {
      final loaded = await _propertiesService.loadFromFile(trimmedServerPath);
      if (loaded != null && snapshot.motdBefore != null) {
        await _propertiesService.saveToFile(
          serverPath: trimmedServerPath,
          settings: loaded.copyWith(description: snapshot.motdBefore),
        );
      }
      await _restoreIcon(trimmedServerPath, snapshot.iconBeforePath);
    }

    await _upsertState({
      'id': 1,
      'is_active': 0,
      'mode': snapshot.mode.storageValue,
      'starts_at': null,
      'ends_at': DateTime.now().toIso8601String(),
      'countdown_seconds': 0,
      'updated_at': DateTime.now().toIso8601String(),
    });
    return loadSnapshot();
  }

  Future<Set<String>> loadAdminNicknames() async {
    final defaults = await loadDefaults();
    final result = <String>{};
    for (final part in defaults.adminNicknames.split(',')) {
      final nickname = part.trim();
      if (nickname.isNotEmpty) {
        result.add(nickname.toLowerCase());
      }
    }
    return result;
  }

  Future<bool> isPlayerAllowed({
    required MaintenanceMode mode,
    required String nickname,
  }) async {
    if (mode == MaintenanceMode.total) {
      return false;
    }
    final admins = await loadAdminNicknames();
    return admins.contains(nickname.trim().toLowerCase());
  }

  Future<List<String>> resolveUnauthorizedPlayers({
    required MaintenanceMode mode,
    required List<String> onlinePlayers,
  }) async {
    if (mode == MaintenanceMode.total) {
      return onlinePlayers
          .map((name) => name.trim())
          .where((name) => name.isNotEmpty)
          .toList();
    }
    final admins = await loadAdminNicknames();
    final blocked = <String>[];
    for (final raw in onlinePlayers) {
      final nickname = raw.trim();
      if (nickname.isEmpty) continue;
      if (!admins.contains(nickname.toLowerCase())) {
        blocked.add(nickname);
      }
    }
    return blocked;
  }

  Future<void> sendMaintenanceMessage(
    SendCommandFn sendCommand,
    String message,
  ) async {
    await sendCommand(_commands.say(message, prefix: '[SERVER 🤖]'));
  }

  Future<void> kickPlayer(
    SendCommandFn sendCommand, {
    required String nickname,
    required String reason,
  }) async {
    await sendCommand(_commands.kick(nickname, reason));
  }

  Future<void> _upsertState(Map<String, Object?> values) async {
    final db = await _db.database;
    await db.insert(
      'maintenance_state',
      values,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String> _resolveMaintenanceIconPath(String fallback) async {
    final configured = await _db.getSetting('maintenance_icon_default_path');
    final candidate = (configured ?? fallback).trim();
    return candidate;
  }

  Future<String?> _backupCurrentServerIcon(String serverPath) async {
    final current = _findCurrentServerIcon(serverPath);
    if (current == null || !await current.exists()) {
      return null;
    }
    final ext = p.extension(current.path);
    final targetDir = await _maintenanceStorageDir();
    await targetDir.create(recursive: true);
    final target = File(
      p.join(
        targetDir.path,
        'icon_before_${DateTime.now().millisecondsSinceEpoch}$ext',
      ),
    );
    await current.copy(target.path);
    return target.path;
  }

  Future<String?> _applyMaintenanceIcon(
    String serverPath,
    String configuredIconPath,
  ) async {
    final source = File(configuredIconPath.trim());
    if (configuredIconPath.trim().isEmpty || !await source.exists()) {
      return null;
    }

    await _clearServerIcons(serverPath);
    final target = File(p.join(serverPath, 'server-icon.png'));
    await source.copy(target.path);
    return source.path;
  }

  Future<void> _restoreIcon(String serverPath, String? backupPath) async {
    await _clearServerIcons(serverPath);
    if (backupPath == null || backupPath.trim().isEmpty) {
      return;
    }
    final source = File(backupPath);
    if (!await source.exists()) {
      return;
    }
    final target = File(p.join(serverPath, 'server-icon.png'));
    await source.copy(target.path);
  }

  Future<void> _clearServerIcons(String serverPath) async {
    for (final fileName in _iconCandidates) {
      final file = File(p.join(serverPath, fileName));
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  File? _findCurrentServerIcon(String serverPath) {
    for (final fileName in _iconCandidates) {
      final file = File(p.join(serverPath, fileName));
      if (file.existsSync()) {
        return file;
      }
    }
    return null;
  }

  Future<Directory> _maintenanceStorageDir() async {
    final appDir = await getApplicationSupportDirectory();
    return Directory(p.join(appDir.path, 'maintenance'));
  }
}
