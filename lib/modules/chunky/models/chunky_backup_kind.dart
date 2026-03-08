import '../../backup/models/backup_entry.dart';

enum ChunkyBackupKind { full, world, selective }

extension ChunkyBackupKindX on ChunkyBackupKind {
  String get storageValue => switch (this) {
    ChunkyBackupKind.full => 'full',
    ChunkyBackupKind.world => 'world',
    ChunkyBackupKind.selective => 'selective',
  };

  String get label => switch (this) {
    ChunkyBackupKind.full => 'Servidor (total)',
    ChunkyBackupKind.world => 'Mundo',
    ChunkyBackupKind.selective => 'Seletivo',
  };

  BackupContentKind get backupContentKind => switch (this) {
    ChunkyBackupKind.full => BackupContentKind.full,
    ChunkyBackupKind.world => BackupContentKind.world,
    ChunkyBackupKind.selective => BackupContentKind.selective,
  };

  static ChunkyBackupKind fromStorage(String raw) {
    return switch (raw.trim().toLowerCase()) {
      'world' => ChunkyBackupKind.world,
      'selective' => ChunkyBackupKind.selective,
      _ => ChunkyBackupKind.full,
    };
  }
}
