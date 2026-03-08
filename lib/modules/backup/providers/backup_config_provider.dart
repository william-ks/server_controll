import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../models/backup_config_settings.dart';

final backupConfigInitialProvider = Provider<BackupConfigSettings>(
  (_) => BackupConfigSettings.defaults(),
);

final backupConfigProvider =
    NotifierProvider<BackupConfigNotifier, BackupConfigSettings>(
      BackupConfigNotifier.new,
    );

class BackupConfigNotifier extends Notifier<BackupConfigSettings> {
  @override
  BackupConfigSettings build() {
    return ref.watch(backupConfigInitialProvider);
  }

  Future<void> loadFromDb() async {
    state = await BackupConfigSettings.fromDatabase(AppDatabase.instance);
  }

  Future<void> refresh() async {
    await loadFromDb();
  }

  Future<void> saveToDb(BackupConfigSettings settings) async {
    await AppDatabase.instance.setSetting('backup_path', settings.backupPath);
    await AppDatabase.instance.setSetting(
      'backup_enabled',
      settings.backupsEnabled ? '1' : '0',
    );
    await AppDatabase.instance.setSetting(
      'backup_retention_max_gb',
      settings.retentionMaxGb,
    );
    await AppDatabase.instance.setSetting(
      'backup_auto_cleanup',
      settings.autoCleanupEnabled ? '1' : '0',
    );
    await AppDatabase.instance.setSetting(
      'backup_capacity_warn_percent',
      '${settings.capacityWarnThresholdPercent}',
    );
    state = settings;
  }
}
