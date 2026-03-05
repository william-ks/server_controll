import '../../../database/app_database.dart';

class BackupConfigSettings {
  const BackupConfigSettings({
    required this.backupPath,
    required this.backupsEnabled,
    required this.maxBackups,
  });

  final String backupPath;
  final bool backupsEnabled;
  final String maxBackups;

  factory BackupConfigSettings.defaults() {
    return const BackupConfigSettings(
      backupPath: '',
      backupsEnabled: false,
      maxBackups: '5',
    );
  }

  static Future<BackupConfigSettings> fromDatabase(AppDatabase db) async {
    final backupPath = await db.getSetting('backup_path') ?? '';
    final backupsEnabledRaw = await db.getSetting('backup_enabled') ?? '0';
    final maxBackups = await db.getSetting('backup_max_count') ?? '5';

    return BackupConfigSettings(
      backupPath: backupPath,
      backupsEnabled: backupsEnabledRaw == '1',
      maxBackups: maxBackups,
    );
  }
}
