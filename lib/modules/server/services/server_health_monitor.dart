import 'dart:async';

import 'minecraft_command_provider.dart';
import 'server_log_parser.dart';

enum ServerHealthState { normal, overloaded, mitigating, recovering, blocked }

extension ServerHealthStateX on ServerHealthState {
  String get label => switch (this) {
    ServerHealthState.normal => 'NORMAL',
    ServerHealthState.overloaded => 'OVERLOADED',
    ServerHealthState.mitigating => 'MITIGATING',
    ServerHealthState.recovering => 'RECOVERING',
    ServerHealthState.blocked => 'BLOCKED',
  };
}

class ServerHealthSnapshot {
  const ServerHealthSnapshot({
    required this.state,
    required this.overloadEventsInWindow,
    required this.restartsInLastHour,
    this.lastMsBehind,
    this.lastTicksBehind,
    this.message,
  });

  final ServerHealthState state;
  final int overloadEventsInWindow;
  final int restartsInLastHour;
  final int? lastMsBehind;
  final int? lastTicksBehind;
  final String? message;

  factory ServerHealthSnapshot.initial() {
    return const ServerHealthSnapshot(
      state: ServerHealthState.normal,
      overloadEventsInWindow: 0,
      restartsInLastHour: 0,
    );
  }

  ServerHealthSnapshot copyWith({
    ServerHealthState? state,
    int? overloadEventsInWindow,
    int? restartsInLastHour,
    int? lastMsBehind,
    int? lastTicksBehind,
    String? message,
    bool clearMessage = false,
  }) {
    return ServerHealthSnapshot(
      state: state ?? this.state,
      overloadEventsInWindow:
          overloadEventsInWindow ?? this.overloadEventsInWindow,
      restartsInLastHour: restartsInLastHour ?? this.restartsInLastHour,
      lastMsBehind: lastMsBehind ?? this.lastMsBehind,
      lastTicksBehind: lastTicksBehind ?? this.lastTicksBehind,
      message: clearMessage ? null : (message ?? this.message),
    );
  }
}

class ServerHealthMonitor {
  ServerHealthMonitor({
    required Future<void> Function(String command) sendCommand,
    required Future<bool> Function({Duration timeout}) waitForOffline,
    required Future<void> Function() startServer,
    required Future<void> Function() waitForOnline,
    required Future<void> Function(String message, {String level}) appendLog,
    required Future<void> Function(ServerHealthSnapshot snapshot) onSnapshot,
    required bool Function() canMitigate,
    this.overloadMessageThreshold = 5,
    this.overloadWindowSeconds = 30,
    this.msBehindLimit = 1500,
    this.stabilizationWaitSeconds = 90,
    this.maxRestartsPerHour = 3,
  }) : _sendCommand = sendCommand,
       _waitForOffline = waitForOffline,
       _startServer = startServer,
       _waitForOnline = waitForOnline,
       _appendLog = appendLog,
       _onSnapshot = onSnapshot,
       _canMitigate = canMitigate;

  final Future<void> Function(String command) _sendCommand;
  final Future<bool> Function({Duration timeout}) _waitForOffline;
  final Future<void> Function() _startServer;
  final Future<void> Function() _waitForOnline;
  final Future<void> Function(String message, {String level}) _appendLog;
  final Future<void> Function(ServerHealthSnapshot snapshot) _onSnapshot;
  final bool Function() _canMitigate;

  final int overloadMessageThreshold;
  final int overloadWindowSeconds;
  final int msBehindLimit;
  final int stabilizationWaitSeconds;
  final int maxRestartsPerHour;

  final List<DateTime> _overloadEvents = <DateTime>[];
  final List<DateTime> _restartEvents = <DateTime>[];
  DateTime? _lastOverloadAt;
  bool _mitigationInProgress = false;
  ServerHealthSnapshot _snapshot = ServerHealthSnapshot.initial();
  static const _commands = MinecraftCommandProvider.vanilla;

  ServerHealthSnapshot get snapshot => _snapshot;

  Future<void> reset() async {
    _overloadEvents.clear();
    _lastOverloadAt = null;
    _mitigationInProgress = false;
    _prune(DateTime.now());
    _snapshot = ServerHealthSnapshot.initial().copyWith(
      restartsInLastHour: _restartEvents.length,
    );
    await _onSnapshot(_snapshot);
  }

  Future<void> handleStdoutLine(
    String line, {
    required String metricsSnapshot,
  }) async {
    final overload = ServerLogParser.parseOverload(line);
    if (overload == null) return;

    final now = DateTime.now();
    _overloadEvents.add(now);
    _lastOverloadAt = now;
    _prune(now);

    final shouldMitigate =
        overload.msBehind >= msBehindLimit ||
        _overloadEvents.length >= overloadMessageThreshold;
    final message =
        'Overload detectado: ${overload.msBehind}ms / ${overload.ticksBehind} ticks (janela: ${_overloadEvents.length}/$overloadMessageThreshold). $metricsSnapshot';

    _snapshot = _snapshot.copyWith(
      state: shouldMitigate
          ? ServerHealthState.overloaded
          : _snapshot.state == ServerHealthState.normal
          ? ServerHealthState.overloaded
          : _snapshot.state,
      overloadEventsInWindow: _overloadEvents.length,
      restartsInLastHour: _restartEvents.length,
      lastMsBehind: overload.msBehind,
      lastTicksBehind: overload.ticksBehind,
      message: message,
    );
    await _onSnapshot(_snapshot);
    await _appendLog(message, level: 'WARN');

    if (_mitigationInProgress || !_canMitigate() || !shouldMitigate) return;
    unawaited(
      _runMitigation(
        msBehind: overload.msBehind,
        ticksBehind: overload.ticksBehind,
      ),
    );
  }

  Future<void> _runMitigation({
    required int msBehind,
    required int ticksBehind,
  }) async {
    _mitigationInProgress = true;
    try {
      await _setState(
        ServerHealthState.mitigating,
        message:
            'Mitigacao leve iniciada para overload $msBehind'
            'ms/$ticksBehind ticks.',
      );

      await _sendCommand(_commands.chunkyPause());
      await _sendCommand(_commands.saveAll(flush: true));
      await _appendLog(
        'Mitigação leve: chunky pause + save-all flush executados.',
        level: 'WARN',
      );

      await Future<void>.delayed(Duration(seconds: stabilizationWaitSeconds));
      _prune(DateTime.now());
      final stable = _isStableForWindow();
      if (stable) {
        await _sendCommand(_commands.chunkyContinue());
        await _setState(
          ServerHealthState.normal,
          message: 'Servidor estabilizado; chunky continue executado.',
        );
        return;
      }

      await _setState(
        ServerHealthState.recovering,
        message: 'Overload persistente apos flush; iniciando mitigacao forte.',
      );

      if (_restartEvents.length >= maxRestartsPerHour) {
        await _setState(
          ServerHealthState.blocked,
          message:
              'Limite de reinicios atingido ($maxRestartsPerHour/h). Intervencao manual requerida.',
        );
        await _appendLog(
          'Mitigação forte bloqueada: limite de reinícios por hora atingido.',
          level: 'ERROR',
        );
        return;
      }

      await _sendCommand(_commands.chunkyPause());
      await _sendCommand(_commands.saveAll(flush: true));
      await _sendCommand(_commands.stopServer());

      final offline = await _waitForOffline(
        timeout: const Duration(seconds: 120),
      );
      if (!offline) {
        throw StateError('Timeout aguardando servidor offline na mitigação.');
      }

      _restartEvents.add(DateTime.now());
      _prune(DateTime.now());
      await _appendLog(
        'Servidor parado com sucesso. Reiniciando para recuperar estabilidade.',
        level: 'WARN',
      );

      await _startServer();
      await _waitForOnline();
      await _sendCommand(_commands.chunkyContinue());

      await _setState(
        ServerHealthState.normal,
        message:
            'Mitigação forte concluída: servidor reiniciado e chunky continue executado.',
      );
    } catch (error) {
      await _setState(
        ServerHealthState.blocked,
        message: 'Falha na mitigação automática: $error',
      );
      await _appendLog('Falha na mitigação automática: $error', level: 'ERROR');
    } finally {
      _mitigationInProgress = false;
    }
  }

  Future<void> _setState(ServerHealthState state, {String? message}) async {
    _prune(DateTime.now());
    _snapshot = _snapshot.copyWith(
      state: state,
      overloadEventsInWindow: _overloadEvents.length,
      restartsInLastHour: _restartEvents.length,
      message: message,
      clearMessage: message == null,
    );
    await _onSnapshot(_snapshot);
  }

  bool _isStableForWindow() {
    final last = _lastOverloadAt;
    if (last == null) return true;
    final window = Duration(seconds: overloadWindowSeconds);
    return DateTime.now().difference(last) >= window;
  }

  void _prune(DateTime now) {
    final overloadWindow = Duration(seconds: overloadWindowSeconds);
    _overloadEvents.removeWhere(
      (timestamp) => now.difference(timestamp) > overloadWindow,
    );
    const restartWindow = Duration(hours: 1);
    _restartEvents.removeWhere(
      (timestamp) => now.difference(timestamp) > restartWindow,
    );
  }
}
