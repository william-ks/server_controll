import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audit/services/audit_service.dart';
import '../../../database/app_database.dart';
import '../models/config_properties_settings.dart';
import '../services/server_properties_service.dart';

final configPropertiesInitialProvider = Provider<ConfigPropertiesSettings>(
  (_) => ConfigPropertiesSettings.defaults(),
);

final serverPropertiesServiceProvider = Provider<ServerPropertiesService>(
  (_) => ServerPropertiesService(),
);

final configPropertiesProvider =
    NotifierProvider<ConfigPropertiesNotifier, ConfigPropertiesSettings>(
      ConfigPropertiesNotifier.new,
    );

class ConfigPropertiesNotifier extends Notifier<ConfigPropertiesSettings> {
  ServerPropertiesService get _service =>
      ref.read(serverPropertiesServiceProvider);

  @override
  ConfigPropertiesSettings build() {
    return ref.watch(configPropertiesInitialProvider);
  }

  Future<void> loadFromSources(String serverPath) async {
    final fromFile = await _service.loadFromFile(serverPath);
    if (fromFile != null) {
      state = fromFile;
      return;
    }
    state = await ConfigPropertiesSettings.fromDatabase(AppDatabase.instance);
  }

  Future<void> saveToDb(ConfigPropertiesSettings settings) async {
    final db = AppDatabase.instance;
    await db.setSetting('prop_level_name', settings.serverName);
    await db.setSetting('prop_motd', settings.description);
    await db.setSetting('prop_level_seed', settings.seed);
    await db.setSetting('prop_hardcore', settings.hardcore ? '1' : '0');
    await db.setSetting('prop_gamemode', settings.gameMode);
    await db.setSetting('prop_max_players', settings.maxPlayers);
    await db.setSetting('prop_pvp', settings.pvp ? '1' : '0');
    await db.setSetting('prop_whitelist', settings.whitelist ? '1' : '0');
    await db.setSetting('prop_view_distance', settings.viewDistance);
    await db.setSetting(
      'prop_simulation_distance',
      settings.simulationDistance,
    );
    state = settings;
    await ref
        .read(auditServiceProvider)
        .logEvent(
          eventType: 'config.change',
          entityType: 'server_properties_config',
          actorType: 'app_operator',
          payload: {
            'server_name': settings.serverName,
            'description': settings.description,
            'seed': settings.seed,
            'hardcore': settings.hardcore,
            'game_mode': settings.gameMode,
            'max_players': settings.maxPlayers,
            'pvp': settings.pvp,
            'whitelist': settings.whitelist,
            'view_distance': settings.viewDistance,
            'simulation_distance': settings.simulationDistance,
          },
          resultStatus: 'success',
        );
  }

  Future<void> saveEverywhere({
    required String serverPath,
    required ConfigPropertiesSettings settings,
  }) async {
    await saveToDb(settings);
    await _service.saveToFile(serverPath: serverPath, settings: settings);
    state = settings;
  }
}
