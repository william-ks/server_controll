import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audit/services/audit_service.dart';
import '../../../database/app_database.dart';
import '../models/app_backup_settings.dart';

final appBackupSettingsInitialProvider = Provider<AppBackupSettings>(
  (_) => AppBackupSettings.defaults(),
);

final appBackupSettingsProvider =
    NotifierProvider<AppBackupSettingsNotifier, AppBackupSettings>(
      AppBackupSettingsNotifier.new,
    );

class AppBackupSettingsNotifier extends Notifier<AppBackupSettings> {
  @override
  AppBackupSettings build() {
    Future<void>(() => refresh());
    return ref.watch(appBackupSettingsInitialProvider);
  }

  Future<void> refresh() async {
    state = await AppBackupSettings.fromDatabase(AppDatabase.instance);
  }

  Future<void> saveToDb(AppBackupSettings settings) async {
    final db = AppDatabase.instance;
    await db.setSetting('app_backup_path', settings.backupPath);
    await db.setSetting(
      'app_backup_auto_enabled',
      settings.autoEnabled ? '1' : '0',
    );
    await db.setSetting('app_backup_cron', settings.cronExpression);
    state = settings;
    await ref
        .read(auditServiceProvider)
        .logEvent(
          eventType: 'config.change',
          entityType: 'app_backup_config',
          actorType: 'app_operator',
          payload: {
            'backup_path': settings.backupPath,
            'auto_enabled': settings.autoEnabled,
            'cron_expression': settings.cronExpression,
          },
          resultStatus: 'success',
        );
  }
}
