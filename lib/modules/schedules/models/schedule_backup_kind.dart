import '../../backup/models/backup_entry.dart';

enum ScheduleBackupKind { full, world, selective, app }

extension ScheduleBackupKindX on ScheduleBackupKind {
  String get storageValue => switch (this) {
    ScheduleBackupKind.full => 'full',
    ScheduleBackupKind.world => 'world',
    ScheduleBackupKind.selective => 'selective',
    ScheduleBackupKind.app => 'app',
  };

  String get label => switch (this) {
    ScheduleBackupKind.full => 'Servidor',
    ScheduleBackupKind.world => 'Mundo',
    ScheduleBackupKind.selective => 'Seletivo',
    ScheduleBackupKind.app => 'App',
  };

  bool get usesWorldState => switch (this) {
    ScheduleBackupKind.full => true,
    ScheduleBackupKind.world => true,
    ScheduleBackupKind.selective => true,
    ScheduleBackupKind.app => false,
  };

  BackupContentKind get backupContentKind => switch (this) {
    ScheduleBackupKind.full => BackupContentKind.full,
    ScheduleBackupKind.world => BackupContentKind.world,
    ScheduleBackupKind.selective => BackupContentKind.selective,
    ScheduleBackupKind.app => BackupContentKind.app,
  };

  static ScheduleBackupKind fromStorage(String raw) {
    return switch (raw.trim().toLowerCase()) {
      'full' => ScheduleBackupKind.full,
      'world' => ScheduleBackupKind.world,
      'selective' => ScheduleBackupKind.selective,
      'app' => ScheduleBackupKind.app,
      _ => ScheduleBackupKind.full,
    };
  }
}
