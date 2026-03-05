enum BackupKind { manual, schedule, chunk, unknown }

class BackupEntry {
  const BackupEntry({
    required this.name,
    required this.path,
    required this.sizeBytes,
    required this.modifiedAt,
    required this.kind,
  });

  final String name;
  final String path;
  final int sizeBytes;
  final DateTime modifiedAt;
  final BackupKind kind;
}
