import '../../../database/app_database.dart';

class AppBackupSettings {
  const AppBackupSettings({
    required this.backupPath,
    required this.autoEnabled,
    required this.cronExpression,
  });

  final String backupPath;
  final bool autoEnabled;
  final String cronExpression;

  factory AppBackupSettings.defaults() {
    return const AppBackupSettings(
      backupPath: '',
      autoEnabled: false,
      cronExpression: '0 */6 * * *',
    );
  }

  static Future<AppBackupSettings> fromDatabase(AppDatabase db) async {
    final backupPath = await db.getSetting('app_backup_path') ?? '';
    final autoEnabledRaw =
        await db.getSetting('app_backup_auto_enabled') ?? '0';
    final cronExpression =
        await db.getSetting('app_backup_cron') ?? '0 */6 * * *';
    return AppBackupSettings(
      backupPath: backupPath,
      autoEnabled: autoEnabledRaw == '1',
      cronExpression: cronExpression,
    );
  }
}
