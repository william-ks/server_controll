enum BackupOriginKind { manual, schedule, chunk, unknown }

enum BackupContentKind { full, world, selective, app, unknown }

class BackupEntry {
  const BackupEntry({
    required this.name,
    required this.path,
    required this.sizeBytes,
    required this.modifiedAt,
    required this.origin,
    required this.contentKind,
    required this.timestamp,
    this.description,
  });

  final String name;
  final String path;
  final int sizeBytes;
  final DateTime modifiedAt;
  final BackupOriginKind origin;
  final BackupContentKind contentKind;
  final DateTime timestamp;
  final String? description;
}
