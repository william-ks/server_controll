import '../../../database/app_database.dart';

class ConfigPropertiesSettings {
  const ConfigPropertiesSettings({
    required this.serverName,
    required this.description,
    required this.seed,
    required this.hardcore,
    required this.gameMode,
    required this.maxPlayers,
    required this.pvp,
    required this.whitelist,
    required this.viewDistance,
    required this.simulationDistance,
  });

  final String serverName;
  final String description;
  final String seed;
  final bool hardcore;
  final String gameMode;
  final String maxPlayers;
  final bool pvp;
  final bool whitelist;
  final String viewDistance;
  final String simulationDistance;

  ConfigPropertiesSettings copyWith({
    String? serverName,
    String? description,
    String? seed,
    bool? hardcore,
    String? gameMode,
    String? maxPlayers,
    bool? pvp,
    bool? whitelist,
    String? viewDistance,
    String? simulationDistance,
  }) {
    return ConfigPropertiesSettings(
      serverName: serverName ?? this.serverName,
      description: description ?? this.description,
      seed: seed ?? this.seed,
      hardcore: hardcore ?? this.hardcore,
      gameMode: gameMode ?? this.gameMode,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      pvp: pvp ?? this.pvp,
      whitelist: whitelist ?? this.whitelist,
      viewDistance: viewDistance ?? this.viewDistance,
      simulationDistance: simulationDistance ?? this.simulationDistance,
    );
  }

  factory ConfigPropertiesSettings.defaults() {
    return const ConfigPropertiesSettings(
      serverName: 'world',
      description: 'A Minecraft Server',
      seed: '',
      hardcore: false,
      gameMode: 'survival',
      maxPlayers: '20',
      pvp: true,
      whitelist: false,
      viewDistance: '10',
      simulationDistance: '10',
    );
  }

  static Future<ConfigPropertiesSettings> fromDatabase(AppDatabase db) async {
    final defaults = ConfigPropertiesSettings.defaults();
    return ConfigPropertiesSettings(
      serverName: await db.getSetting('prop_level_name') ?? defaults.serverName,
      description: await db.getSetting('prop_motd') ?? defaults.description,
      seed: await db.getSetting('prop_level_seed') ?? defaults.seed,
      hardcore: (await db.getSetting('prop_hardcore') ?? '0') == '1',
      gameMode: await db.getSetting('prop_gamemode') ?? defaults.gameMode,
      maxPlayers:
          await db.getSetting('prop_max_players') ?? defaults.maxPlayers,
      pvp: (await db.getSetting('prop_pvp') ?? '1') == '1',
      whitelist: (await db.getSetting('prop_whitelist') ?? '0') == '1',
      viewDistance:
          await db.getSetting('prop_view_distance') ?? defaults.viewDistance,
      simulationDistance:
          await db.getSetting('prop_simulation_distance') ??
          defaults.simulationDistance,
    );
  }
}
