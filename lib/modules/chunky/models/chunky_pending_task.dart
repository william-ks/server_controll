class ChunkyPendingTask {
  const ChunkyPendingTask({
    required this.filePath,
    required this.world,
    required this.cancelled,
    required this.centerX,
    required this.centerZ,
    required this.radius,
    required this.shape,
    required this.pattern,
    required this.chunks,
    required this.time,
  });

  final String filePath;
  final String world;
  final bool cancelled;
  final double centerX;
  final double centerZ;
  final double radius;
  final String shape;
  final String pattern;
  final int chunks;
  final int time;
}
