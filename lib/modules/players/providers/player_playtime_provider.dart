import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/server_lifecycle_state.dart';
import '../../../models/server_runtime_state.dart';
import '../../server/providers/server_runtime_provider.dart';
import '../../server/services/server_log_parser.dart';
import '../models/player_playtime_summary.dart';
import '../models/player_session_entry.dart';
import '../repositories/player_playtime_repository.dart';

class PlayerPlaytimeState {
  const PlayerPlaytimeState({
    required this.loading,
    required this.syncing,
    required this.ranking,
    required this.selectedPlayerId,
    required this.selectedHistory,
    this.lastTickAt,
    this.error,
  });

  final bool loading;
  final bool syncing;
  final List<PlayerPlaytimeSummary> ranking;
  final int? selectedPlayerId;
  final List<PlayerSessionEntry> selectedHistory;
  final DateTime? lastTickAt;
  final String? error;

  PlayerPlaytimeState copyWith({
    bool? loading,
    bool? syncing,
    List<PlayerPlaytimeSummary>? ranking,
    int? selectedPlayerId,
    List<PlayerSessionEntry>? selectedHistory,
    DateTime? lastTickAt,
    String? error,
    bool clearError = false,
  }) {
    return PlayerPlaytimeState(
      loading: loading ?? this.loading,
      syncing: syncing ?? this.syncing,
      ranking: ranking ?? this.ranking,
      selectedPlayerId: selectedPlayerId ?? this.selectedPlayerId,
      selectedHistory: selectedHistory ?? this.selectedHistory,
      lastTickAt: lastTickAt ?? this.lastTickAt,
      error: clearError ? null : (error ?? this.error),
    );
  }

  factory PlayerPlaytimeState.initial() {
    return const PlayerPlaytimeState(
      loading: false,
      syncing: false,
      ranking: [],
      selectedPlayerId: null,
      selectedHistory: [],
    );
  }
}

final playerPlaytimeRepositoryProvider = Provider<PlayerPlaytimeRepository>(
  (_) => PlayerPlaytimeRepository(),
);

final playerPlaytimeProvider =
    NotifierProvider<PlayerPlaytimeNotifier, PlayerPlaytimeState>(
      PlayerPlaytimeNotifier.new,
    );

class PlayerPlaytimeNotifier extends Notifier<PlayerPlaytimeState> {
  PlayerPlaytimeRepository get _repository =>
      ref.read(playerPlaytimeRepositoryProvider);

  Timer? _tickTimer;
  StreamSubscription<String>? _stdoutSub;
  bool _tickRunning = false;

  @override
  PlayerPlaytimeState build() {
    ref.listen<ServerRuntimeState>(serverRuntimeProvider, (previous, next) {
      unawaited(_onRuntimeChanged(previous, next));
    });

    final processService = ref.read(serverProcessServiceProvider);
    _stdoutSub = processService.stdoutLines.listen((line) {
      final kicked = ServerLogParser.parseKickedPlayer(line);
      if (kicked == null || kicked.isEmpty) {
        return;
      }
      unawaited(
        _repository
            .closeSessionForNickname(kicked, reason: 'kick', incomplete: false)
            .then((changed) async {
              if (!changed) return;
              await _refresh();
            }),
      );
    });

    Future<void>(() async {
      state = state.copyWith(loading: true, clearError: true);
      try {
        await _repository.ensureTickSetting(defaultSeconds: 5);
        await _repository.markOpenSessionsAsUnexpectedShutdown();
        await _refresh();
        await _startTick();
      } catch (error) {
        state = state.copyWith(error: error.toString());
      } finally {
        state = state.copyWith(loading: false);
      }
    });

    ref.onDispose(() {
      _tickTimer?.cancel();
      unawaited(_stdoutSub?.cancel());
    });

    return PlayerPlaytimeState.initial();
  }

  Future<void> selectPlayer(int? playerId) async {
    if (playerId == null) {
      state = state.copyWith(selectedPlayerId: null, selectedHistory: []);
      return;
    }
    final history = await _repository.fetchPlayerHistory(playerId);
    state = state.copyWith(
      selectedPlayerId: playerId,
      selectedHistory: history,
      clearError: true,
    );
  }

  Future<void> refresh() async {
    state = state.copyWith(syncing: true, clearError: true);
    try {
      await _refresh();
    } catch (error) {
      state = state.copyWith(error: error.toString());
    } finally {
      state = state.copyWith(syncing: false);
    }
  }

  Future<void> _startTick() async {
    _tickTimer?.cancel();
    final seconds = await _repository.getTickSeconds(fallback: 5);
    _tickTimer = Timer.periodic(Duration(seconds: seconds), (_) {
      unawaited(_runTick());
    });
  }

  Future<void> _runTick() async {
    if (_tickRunning) return;
    final runtime = ref.read(serverRuntimeProvider);
    if (runtime.lifecycle != ServerLifecycleState.online) {
      return;
    }

    _tickRunning = true;
    try {
      await ref.read(serverRuntimeProvider.notifier).requestOnlinePlayers();
      await Future<void>.delayed(const Duration(milliseconds: 400));
      final online = ref.read(serverRuntimeProvider).onlinePlayers;
      final changed = await _repository.reconcilePresence(
        online,
        closeReason: 'presence_reconciliation',
      );
      if (changed) {
        await _refresh();
      } else {
        state = state.copyWith(lastTickAt: DateTime.now());
      }
    } finally {
      _tickRunning = false;
    }
  }

  Future<void> _onRuntimeChanged(
    ServerRuntimeState? previous,
    ServerRuntimeState next,
  ) async {
    var changed = false;

    final previousPlayers = <String, String>{
      for (final name in previous?.onlinePlayers ?? const <String>[])
        if (name.trim().isNotEmpty) name.trim().toLowerCase(): name.trim(),
    };
    final nextPlayers = <String, String>{
      for (final name in next.onlinePlayers)
        if (name.trim().isNotEmpty) name.trim().toLowerCase(): name.trim(),
    };

    final joined = nextPlayers.keys.toSet().difference(
      previousPlayers.keys.toSet(),
    );
    final left = previousPlayers.keys.toSet().difference(
      nextPlayers.keys.toSet(),
    );

    for (final nicknameKey in joined) {
      final nickname = nextPlayers[nicknameKey] ?? nicknameKey;
      final opened = await _repository.openSessionForNickname(nickname);
      if (opened) {
        changed = true;
      }
    }
    for (final nicknameKey in left) {
      final nickname = previousPlayers[nicknameKey] ?? nicknameKey;
      final closed = await _repository.closeSessionForNickname(
        nickname,
        reason: 'leave',
      );
      if (closed) {
        changed = true;
      }
    }

    final wasOnline = previous?.lifecycle == ServerLifecycleState.online;
    final nowOnline = next.lifecycle == ServerLifecycleState.online;
    if (wasOnline && !nowOnline) {
      final closeReason = switch (next.lifecycle) {
        ServerLifecycleState.restarting => 'restart',
        ServerLifecycleState.stopping => 'stop',
        _ => 'stop',
      };
      final closed = await _repository.closeAllOpenSessions(
        reason: closeReason,
        incomplete: false,
      );
      if (closed) {
        changed = true;
      }
    }

    if (changed) {
      await _refresh();
    }
  }

  Future<void> _refresh() async {
    final ranking = await _repository.fetchRanking();
    var selectedPlayerId = state.selectedPlayerId;
    if (selectedPlayerId == null ||
        !ranking.any((item) => item.playerId == selectedPlayerId)) {
      selectedPlayerId = ranking.isEmpty ? null : ranking.first.playerId;
    }

    List<PlayerSessionEntry> history = const [];
    if (selectedPlayerId != null) {
      history = await _repository.fetchPlayerHistory(selectedPlayerId);
    }

    state = state.copyWith(
      ranking: ranking,
      selectedPlayerId: selectedPlayerId,
      selectedHistory: history,
      lastTickAt: DateTime.now(),
      clearError: true,
    );
  }
}
