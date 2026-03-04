import 'server_lifecycle_state.dart';

class ServerRuntimeState {
  const ServerRuntimeState({
    required this.lifecycle,
    required this.uptime,
    required this.activePlayers,
    this.lastError,
    this.startedAt,
    this.readyAt,
  });

  final ServerLifecycleState lifecycle;
  final Duration uptime;
  final int activePlayers;
  final String? lastError;
  final DateTime? startedAt;
  final DateTime? readyAt;

  bool get isOnline => lifecycle == ServerLifecycleState.online;

  ServerRuntimeState copyWith({
    ServerLifecycleState? lifecycle,
    Duration? uptime,
    int? activePlayers,
    String? lastError,
    DateTime? startedAt,
    DateTime? readyAt,
    bool clearError = false,
  }) {
    return ServerRuntimeState(
      lifecycle: lifecycle ?? this.lifecycle,
      uptime: uptime ?? this.uptime,
      activePlayers: activePlayers ?? this.activePlayers,
      lastError: clearError ? null : (lastError ?? this.lastError),
      startedAt: startedAt ?? this.startedAt,
      readyAt: readyAt ?? this.readyAt,
    );
  }

  factory ServerRuntimeState.initial() {
    return const ServerRuntimeState(
      lifecycle: ServerLifecycleState.offline,
      uptime: Duration.zero,
      activePlayers: 0,
    );
  }
}
