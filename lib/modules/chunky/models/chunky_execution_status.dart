enum ChunkyExecutionStatus {
  idle,
  awaitingResume,
  running,
  paused,
  cancelling,
  completed,
  error,
}

extension ChunkyExecutionStatusX on ChunkyExecutionStatus {
  String get label => switch (this) {
    ChunkyExecutionStatus.idle => 'IDLE',
    ChunkyExecutionStatus.awaitingResume => 'AGUARDANDO ACAO',
    ChunkyExecutionStatus.running => 'RUNNING',
    ChunkyExecutionStatus.paused => 'PAUSED',
    ChunkyExecutionStatus.cancelling => 'CANCELLING',
    ChunkyExecutionStatus.completed => 'COMPLETED',
    ChunkyExecutionStatus.error => 'ERROR',
  };
}
