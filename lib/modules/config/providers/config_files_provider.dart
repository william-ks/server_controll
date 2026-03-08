import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audit/services/audit_service.dart';
import '../../../database/app_database.dart';
import '../models/config_files_settings.dart';

final configFilesInitialProvider = Provider<ConfigFilesSettings>(
  (_) => ConfigFilesSettings.defaults(),
);

final configFilesProvider =
    NotifierProvider<ConfigFilesNotifier, ConfigFilesSettings>(
      ConfigFilesNotifier.new,
    );

class ConfigFilesNotifier extends Notifier<ConfigFilesSettings> {
  @override
  ConfigFilesSettings build() {
    return ref.watch(configFilesInitialProvider);
  }

  Future<void> loadFromDb() async {
    state = await ConfigFilesSettings.fromDatabase(AppDatabase.instance);
  }

  Future<void> refresh() async {
    await loadFromDb();
  }

  Future<void> saveToDb(ConfigFilesSettings settings) async {
    final db = AppDatabase.instance;
    await db.setSetting('server_path', settings.serverPath);
    await db.setSetting('ram_min_gb', settings.ramMinGb);
    await db.setSetting('ram_max_gb', settings.ramMaxGb);
    await db.setSetting('file_server_name', settings.fileServerName);
    await db.setSetting('java_command', settings.javaCommand);
    await db.setSetting('jvm_args', settings.jvmArgs);
    await db.setSetting(
      'auto_restart_on_crash',
      settings.autoRestartOnCrash ? '1' : '0',
    );
    await db.setSetting('restart_wait_seconds', settings.restartWaitSeconds);

    // Backward-compatible keys already used by runtime/service layers
    await db.setSetting('server_dir', settings.serverPath);
    await db.setSetting('jar_file', settings.fileServerName);
    await db.setSetting(
      'xms',
      settings.ramMinGb.isEmpty ? '' : '${settings.ramMinGb}G',
    );
    await db.setSetting(
      'xmx',
      settings.ramMaxGb.isEmpty ? '' : '${settings.ramMaxGb}G',
    );

    state = settings;
    await ref
        .read(auditServiceProvider)
        .logEvent(
          eventType: 'config.change',
          entityType: 'config_files',
          actorType: 'app_operator',
          payload: {
            'server_path': settings.serverPath,
            'ram_min_gb': settings.ramMinGb,
            'ram_max_gb': settings.ramMaxGb,
            'jar_file': settings.fileServerName,
            'java_command': settings.javaCommand,
            'jvm_args': settings.jvmArgs,
            'auto_restart_on_crash': settings.autoRestartOnCrash,
            'restart_wait_seconds': settings.restartWaitSeconds,
          },
          resultStatus: 'success',
        );
  }
}
