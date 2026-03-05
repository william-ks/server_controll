import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/config_properties_settings.dart';

class ServerPropertiesService {
  static const String _fileName = 'server.properties';

  static const String keyLevelName = 'level-name';
  static const String keyMotd = 'motd';
  static const String keyLevelSeed = 'level-seed';
  static const String keyHardcore = 'hardcore';
  static const String keyGamemode = 'gamemode';
  static const String keyMaxPlayers = 'max-players';
  static const String keyPvp = 'pvp';
  static const String keyWhitelist = 'white-list';
  static const String keyViewDistance = 'view-distance';
  static const String keySimulationDistance = 'simulation-distance';

  static const List<String> managedKeys = [
    keyLevelName,
    keyMotd,
    keyLevelSeed,
    keyHardcore,
    keyGamemode,
    keyMaxPlayers,
    keyPvp,
    keyWhitelist,
    keyViewDistance,
    keySimulationDistance,
  ];

  File fileForServerPath(String serverPath) {
    return File(p.join(serverPath, _fileName));
  }

  Future<bool> fileExists(String serverPath) async {
    final trimmed = serverPath.trim();
    if (trimmed.isEmpty) return false;
    return fileForServerPath(trimmed).exists();
  }

  Future<ConfigPropertiesSettings?> loadFromFile(String serverPath) async {
    if (!await fileExists(serverPath)) {
      return null;
    }

    final file = fileForServerPath(serverPath.trim());
    final lines = await file.readAsLines();
    final map = <String, String>{};
    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final index = line.indexOf('=');
      if (index <= 0) continue;
      final key = line.substring(0, index).trim();
      final value = line.substring(index + 1);
      map[key] = value;
    }

    final defaults = ConfigPropertiesSettings.defaults();
    return ConfigPropertiesSettings(
      serverName: map[keyLevelName] ?? defaults.serverName,
      description: map[keyMotd] ?? defaults.description,
      seed: map[keyLevelSeed] ?? defaults.seed,
      hardcore: _parseBool(map[keyHardcore], defaults.hardcore),
      gameMode: map[keyGamemode] ?? defaults.gameMode,
      maxPlayers: map[keyMaxPlayers] ?? defaults.maxPlayers,
      pvp: _parseBool(map[keyPvp], defaults.pvp),
      whitelist: _parseBool(map[keyWhitelist], defaults.whitelist),
      viewDistance: map[keyViewDistance] ?? defaults.viewDistance,
      simulationDistance:
          map[keySimulationDistance] ?? defaults.simulationDistance,
    );
  }

  Future<void> saveToFile({
    required String serverPath,
    required ConfigPropertiesSettings settings,
  }) async {
    final file = fileForServerPath(serverPath.trim());
    if (!await file.exists()) {
      throw StateError('Arquivo server.properties não encontrado.');
    }

    final lines = await file.readAsLines();
    final targetMap = _toMap(settings);
    final seen = <String>{};
    final output = <String>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('#') || !trimmed.contains('=')) {
        output.add(line);
        continue;
      }
      final index = trimmed.indexOf('=');
      final key = trimmed.substring(0, index).trim();
      if (targetMap.containsKey(key)) {
        output.add('$key=${targetMap[key]}');
        seen.add(key);
      } else {
        output.add(line);
      }
    }

    for (final key in managedKeys) {
      if (!seen.contains(key)) {
        output.add('$key=${targetMap[key] ?? ''}');
      }
    }

    await file.writeAsString('${output.join('\n')}\n');
  }

  Map<String, String> _toMap(ConfigPropertiesSettings s) {
    return {
      keyLevelName: s.serverName,
      keyMotd: s.description,
      keyLevelSeed: s.seed,
      keyHardcore: s.hardcore ? 'true' : 'false',
      keyGamemode: s.gameMode,
      keyMaxPlayers: s.maxPlayers,
      keyPvp: s.pvp ? 'true' : 'false',
      keyWhitelist: s.whitelist ? 'true' : 'false',
      keyViewDistance: s.viewDistance,
      keySimulationDistance: s.simulationDistance,
    };
  }

  bool _parseBool(String? value, bool fallback) {
    if (value == null) return fallback;
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true') return true;
    if (normalized == 'false') return false;
    return fallback;
  }
}
