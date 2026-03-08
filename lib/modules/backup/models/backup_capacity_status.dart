enum BackupCapacityLevel { normal, warning, reached, exceeded }

class BackupCapacityStatus {
  const BackupCapacityStatus({
    required this.level,
    required this.usedBytes,
    required this.limitBytes,
    required this.usedPercent,
  });

  final BackupCapacityLevel level;
  final int usedBytes;
  final int limitBytes;
  final double usedPercent;

  bool get hasLimit => limitBytes > 0;
}
