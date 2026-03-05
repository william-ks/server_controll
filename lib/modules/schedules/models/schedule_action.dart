enum ScheduleAction { startServer, restartServer, stopServer }

extension ScheduleActionX on ScheduleAction {
  String get storageValue => switch (this) {
    ScheduleAction.startServer => 'start',
    ScheduleAction.restartServer => 'restart',
    ScheduleAction.stopServer => 'stop',
  };

  String get label => switch (this) {
    ScheduleAction.startServer => 'Iniciar servidor',
    ScheduleAction.restartServer => 'Reiniciar servidor',
    ScheduleAction.stopServer => 'Desligar servidor',
  };

  static ScheduleAction fromStorage(String raw) {
    return switch (raw) {
      'start' => ScheduleAction.startServer,
      'stop' => ScheduleAction.stopServer,
      _ => ScheduleAction.restartServer,
    };
  }
}
