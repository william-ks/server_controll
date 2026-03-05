class ChunkyExecutionLogEntry {
  const ChunkyExecutionLogEntry({
    this.id,
    required this.timestamp,
    required this.level,
    required this.message,
    required this.runIndex,
    required this.totalRuns,
    required this.radius,
    required this.elapsed,
  });

  final int? id;
  final DateTime timestamp;
  final String level;
  final String message;
  final int runIndex;
  final int totalRuns;
  final int radius;
  final Duration elapsed;
}
