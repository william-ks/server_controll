import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/server_lifecycle_state.dart';
import '../../../models/server_runtime_state.dart';
import '../../audit/services/audit_service.dart';
import '../../chat_hook/services/chat_hook_service.dart';
import '../services/minecraft_command_provider.dart';
import '../services/server_log_parser.dart';
import '../services/server_process_service.dart';

final serverProcessServiceProvider = Provider<ServerProcessService>((ref) {
  final service = LocalServerProcessService();
  ref.onDispose(() {
    unawaited(service.dispose());
  });
  return service;
});

final serverRuntimeProvider =
    NotifierProvider<ServerRuntimeNotifier, ServerRuntimeState>(
      ServerRuntimeNotifier.new,
    );

final onlinePlayersProvider = Provider<List<String>>((ref) {
  return ref.watch(serverRuntimeProvider).onlinePlayers;
});

class ServerRuntimeNotifier extends Notifier<ServerRuntimeState> {
  static const _commands = MinecraftCommandProvider.vanilla;
  StreamSubscription<String>? _stdoutSub;
  StreamSubscription<String>? _stderrSub;
  StreamSubscription<int>? _exitSub;
  Timer? _uptimeTimer;

  ServerProcessService get _service => ref.read(serverProcessServiceProvider);

  @override
  ServerRuntimeState build() {
    _stdoutSub = _service.stdoutLines.listen(_handleStdout);
    _stderrSub = _service.stderrLines.listen(_handleStderr);
    _exitSub = _service.exitCodes.listen(_handleExit);
    Future<void>(() async {
      await _service.prepareForAppStartup();
      if (await _service.hasAnyServerInstance()) {
        state = state.copyWith(
          lifecycle: ServerLifecycleState.error,
          lastError:
              'Instancia de servidor detectada ao iniciar e nao foi possivel assumir controle.',
        );
      }
    });

    ref.onDispose(() {
      _uptimeTimer?.cancel();
      unawaited(_stdoutSub?.cancel());
      unawaited(_stderrSub?.cancel());
      unawaited(_exitSub?.cancel());
    });

    return ServerRuntimeState.initial();
  }

  Future<void> startServer() async {
    if (state.lifecycle == ServerLifecycleState.online ||
        state.lifecycle == ServerLifecycleState.starting) {
      return;
    }

    state = state.copyWith(
      lifecycle: ServerLifecycleState.starting,
      startedAt: DateTime.now(),
      readyAt: null,
      uptime: Duration.zero,
      activePlayers: 0,
      onlinePlayers: const [],
      clearError: true,
    );

    try {
      await _service.start();
      await ref
          .read(auditServiceProvider)
          .logEvent(
            eventType: 'lifecycle.start',
            entityType: 'server',
            actorType: 'system',
            payload: {'source': 'ui_or_automation'},
            resultStatus: 'success',
          );
    } catch (error) {
      _uptimeTimer?.cancel();
      state = state.copyWith(
        lifecycle: ServerLifecycleState.error,
        lastError: error.toString(),
      );
      await ref
          .read(auditServiceProvider)
          .logEvent(
            eventType: 'lifecycle.start',
            entityType: 'server',
            actorType: 'system',
            payload: {'error': error.toString()},
            resultStatus: 'error',
          );
    }
  }

  Future<void> stopServer() async {
    if (state.lifecycle != ServerLifecycleState.online &&
        state.lifecycle != ServerLifecycleState.starting &&
        state.lifecycle != ServerLifecycleState.restarting) {
      return;
    }
    state = state.copyWith(lifecycle: ServerLifecycleState.stopping);
    try {
      await _service.stop();
      await ref
          .read(auditServiceProvider)
          .logEvent(
            eventType: 'lifecycle.stop',
            entityType: 'server',
            actorType: 'system',
            payload: {'source': 'ui_or_automation'},
            resultStatus: 'success',
          );
    } catch (error) {
      await ref
          .read(auditServiceProvider)
          .logEvent(
            eventType: 'lifecycle.stop',
            entityType: 'server',
            actorType: 'system',
            payload: {'error': error.toString()},
            resultStatus: 'error',
          );
      rethrow;
    }
  }

  Future<void> restartServer() async {
    if (state.lifecycle != ServerLifecycleState.online) {
      return;
    }
    state = state.copyWith(
      lifecycle: ServerLifecycleState.restarting,
      uptime: Duration.zero,
    );
    try {
      await _service.restart();
      state = state.copyWith(
        lifecycle: ServerLifecycleState.starting,
        startedAt: DateTime.now(),
        readyAt: null,
        onlinePlayers: const [],
        activePlayers: 0,
      );
      await ref
          .read(auditServiceProvider)
          .logEvent(
            eventType: 'lifecycle.restart',
            entityType: 'server',
            actorType: 'system',
            payload: {'source': 'ui_or_automation'},
            resultStatus: 'success',
          );
    } catch (error) {
      await ref
          .read(auditServiceProvider)
          .logEvent(
            eventType: 'lifecycle.restart',
            entityType: 'server',
            actorType: 'system',
            payload: {'error': error.toString()},
            resultStatus: 'error',
          );
      rethrow;
    }
  }

  Future<void> sendCommand(String command) async {
    await _service.sendCommand(command);
  }

  Future<void> shutdownForAppExit() async {
    state = state.copyWith(lifecycle: ServerLifecycleState.stopping);
    await _service.shutdownForAppExit();
  }

  Future<void> requestOnlinePlayers() async {
    await sendCommand(_commands.listPlayers());
  }

  void _handleStdout(String line) {
    unawaited(ref.read(chatHookServiceProvider).processStdoutLine(line));

    if (ServerLogParser.isServerReady(line)) {
      final readyAt = DateTime.now();
      state = state.copyWith(
        lifecycle: ServerLifecycleState.online,
        readyAt: readyAt,
        uptime: Duration.zero,
      );
      _startUptimeTicker();
      return;
    }

    final players = ServerLogParser.parsePlayersOnline(line);
    if (players != null) {
      state = state.copyWith(activePlayers: players);
    }

    final playersList = ServerLogParser.parseOnlinePlayersList(line);
    if (playersList != null) {
      state = state.copyWith(
        onlinePlayers: playersList,
        activePlayers: playersList.length,
      );
    }

    final joined = ServerLogParser.parseJoinedPlayer(line);
    if (joined != null && joined.isNotEmpty) {
      final next = List<String>.from(state.onlinePlayers);
      if (!next.contains(joined)) {
        next.add(joined);
      }
      state = state.copyWith(onlinePlayers: next, activePlayers: next.length);
    }

    final left = ServerLogParser.parseLeftPlayer(line);
    if (left != null && left.isNotEmpty) {
      final next = List<String>.from(state.onlinePlayers)..remove(left);
      state = state.copyWith(onlinePlayers: next, activePlayers: next.length);
    }

    if (ServerLogParser.isStopping(line)) {
      state = state.copyWith(lifecycle: ServerLifecycleState.stopping);
    }
  }

  void _handleStderr(String line) {
    if (state.lifecycle == ServerLifecycleState.starting ||
        state.lifecycle == ServerLifecycleState.online) {
      state = state.copyWith(lastError: line);
    }
  }

  void _handleExit(int code) {
    _uptimeTimer?.cancel();
    state = state.copyWith(
      lifecycle: code == 0
          ? ServerLifecycleState.offline
          : ServerLifecycleState.error,
      uptime: Duration.zero,
      activePlayers: 0,
      onlinePlayers: const [],
      startedAt: null,
      readyAt: null,
      lastError: code == 0 ? null : 'Process exited with code $code',
      clearError: code == 0,
    );
    unawaited(
      ref
          .read(auditServiceProvider)
          .logEvent(
            eventType: 'lifecycle.exit',
            entityType: 'server',
            actorType: 'system',
            payload: {'exit_code': code},
            resultStatus: code == 0 ? 'success' : 'error',
          ),
    );
  }

  void _startUptimeTicker() {
    _uptimeTimer?.cancel();
    _uptimeTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final readyAt = state.readyAt;
      if (state.lifecycle != ServerLifecycleState.online || readyAt == null) {
        return;
      }
      state = state.copyWith(uptime: DateTime.now().difference(readyAt));
    });
  }
}
