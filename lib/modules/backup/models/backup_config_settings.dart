import '../../../database/app_database.dart';

class BackupConfigSettings {
  const BackupConfigSettings({
    required this.backupPath,
    required this.backupsEnabled,
    required this.retentionMaxGb,
    required this.autoCleanupEnabled,
    required this.capacityWarnThresholdPercent,
  });

  final String backupPath;
  final bool backupsEnabled;
  final String retentionMaxGb;
  final bool autoCleanupEnabled;
  final int capacityWarnThresholdPercent;

  factory BackupConfigSettings.defaults() {
    return const BackupConfigSettings(
      backupPath: '',
      backupsEnabled: false,
      retentionMaxGb: '0',
      autoCleanupEnabled: true,
      capacityWarnThresholdPercent: 80,
    );
  }

  static Future<BackupConfigSettings> fromDatabase(AppDatabase db) async {
    final backupPath = await db.getSetting('backup_path') ?? '';
    final backupsEnabledRaw = await db.getSetting('backup_enabled') ?? '0';
    final retentionMaxGb =
        await db.getSetting('backup_retention_max_gb') ?? '0';
    final autoCleanupRaw = await db.getSetting('backup_auto_cleanup') ?? '1';
    final warnPercentRaw =
        await db.getSetting('backup_capacity_warn_percent') ?? '80';

    return BackupConfigSettings(
      backupPath: backupPath,
      backupsEnabled: backupsEnabledRaw == '1',
      retentionMaxGb: retentionMaxGb,
      autoCleanupEnabled: autoCleanupRaw == '1',
      capacityWarnThresholdPercent: int.tryParse(warnPercentRaw) ?? 80,
    );
  }
}
