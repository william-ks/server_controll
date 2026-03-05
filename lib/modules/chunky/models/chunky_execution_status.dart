enum ChunkyExecutionStatus {
  idle,
  running,
  paused,
  cancelling,
  completed,
  error,
}

extension ChunkyExecutionStatusX on ChunkyExecutionStatus {
  String get label => switch (this) {
    ChunkyExecutionStatus.idle => 'IDLE',
    ChunkyExecutionStatus.running => 'RUNNING',
    ChunkyExecutionStatus.paused => 'PAUSED',
    ChunkyExecutionStatus.cancelling => 'CANCELLING',
    ChunkyExecutionStatus.completed => 'COMPLETED',
    ChunkyExecutionStatus.error => 'ERROR',
  };
}
