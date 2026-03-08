import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/config_properties_settings.dart';
import '../models/server_properties_field_catalog.dart';

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
    final map = await loadRawProperties(serverPath);
    if (map == null) return null;

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
    final targetMap = _toMap(settings);
    await saveManagedProperties(serverPath: serverPath, managed: targetMap);
  }

  Future<Map<String, String>?> loadRawProperties(String serverPath) async {
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
    return map;
  }

  Future<void> saveManagedProperties({
    required String serverPath,
    required Map<String, String> managed,
  }) async {
    final file = fileForServerPath(serverPath.trim());
    if (!await file.exists()) {
      throw StateError('Arquivo server.properties não encontrado.');
    }

    final lines = await file.readAsLines();
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
      if (managed.containsKey(key)) {
        output.add('$key=${managed[key]}');
        seen.add(key);
      } else {
        output.add(line);
      }
    }

    for (final key in managed.keys) {
      if (!seen.contains(key)) {
        output.add('$key=${managed[key] ?? ''}');
      }
    }

    await file.writeAsString('${output.join('\n')}\n');
  }

  Future<void> setPvpValue({
    required String serverPath,
    required bool enabled,
  }) async {
    final current = await loadFromFile(serverPath);
    if (current == null) {
      throw StateError('Arquivo server.properties não encontrado.');
    }
    final next = current.copyWith(pvp: enabled);
    await saveToFile(serverPath: serverPath, settings: next);
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

  String? validateByCatalog(ServerPropertyFieldDefinition field, String value) {
    final trimmed = value.trim();
    switch (field.type) {
      case ServerPropertyFieldType.boolean:
        final v = trimmed.toLowerCase();
        if (v == 'true' || v == 'false') return null;
        return 'Use true ou false.';
      case ServerPropertyFieldType.integer:
        final parsed = int.tryParse(trimmed);
        if (parsed == null) {
          return 'Informe um número inteiro válido.';
        }
        if (field.minValue != null && parsed < field.minValue!) {
          return 'Valor mínimo: ${field.minValue}.';
        }
        if (field.maxValue != null && parsed > field.maxValue!) {
          return 'Valor máximo: ${field.maxValue}.';
        }
        return null;
      case ServerPropertyFieldType.enumeration:
        if (!field.options.contains(trimmed)) {
          return 'Escolha um valor válido para ${field.label}.';
        }
        return null;
      case ServerPropertyFieldType.string:
        return null;
    }
  }
}
