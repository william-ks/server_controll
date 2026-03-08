import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/server_lifecycle_state.dart';
import '../../../models/server_runtime_state.dart';
import '../../audit/services/audit_service.dart';
import '../../server/providers/server_runtime_provider.dart';
import '../../server/services/minecraft_command_provider.dart';
import '../repositories/player_ban_repository.dart';
import 'player_permissions_provider.dart';

class PlayerBanState {
  const PlayerBanState({required this.syncing, this.error});

  final bool syncing;
  final String? error;

  PlayerBanState copyWith({
    bool? syncing,
    String? error,
    bool clearError = false,
  }) {
    return PlayerBanState(
      syncing: syncing ?? this.syncing,
      error: clearError ? null : (error ?? this.error),
    );
  }

  factory PlayerBanState.initial() {
    return const PlayerBanState(syncing: false);
  }
}

final playerBanRepositoryProvider = Provider<PlayerBanRepository>((ref) {
  return PlayerBanRepository(
    permissionsRepository: ref.read(playerPermissionsRepositoryProvider),
  );
});

final playerBanProvider = NotifierProvider<PlayerBanNotifier, PlayerBanState>(
  PlayerBanNotifier.new,
);

class PlayerBanNotifier extends Notifier<PlayerBanState> {
  static const _commands = MinecraftCommandProvider.vanilla;
  Timer? _tickTimer;

  PlayerBanRepository get _repository => ref.read(playerBanRepositoryProvider);

  @override
  PlayerBanState build() {
    ref.listen<ServerRuntimeState>(serverRuntimeProvider, (previous, next) {
      final becameOnline =
          previous?.lifecycle != ServerLifecycleState.online &&
          next.lifecycle == ServerLifecycleState.online;
      if (becameOnline) {
        unawaited(processBanSync());
      }
    });

    _tickTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(processBanSync());
    });
    Future<void>(() => processBanSync());

    ref.onDispose(() {
      _tickTimer?.cancel();
    });
    return PlayerBanState.initial();
  }

  Future<void> banPlayer({
    required String nickname,
    required String reason,
    Duration? duration,
    String actor = 'app_operator',
  }) async {
    final runtime = ref.read(serverRuntimeProvider);
    final online = runtime.lifecycle == ServerLifecycleState.online;
    try {
      await _repository.banPlayer(
        nickname: nickname,
        reason: reason,
        pendingBan: !online,
        duration: duration,
        createdBy: actor,
      );

      if (online) {
        await ref
            .read(serverRuntimeProvider.notifier)
            .sendCommand(_commands.ban(nickname, reason: reason));
      }
      await ref
          .read(auditServiceProvider)
          .logEvent(
            eventType: 'ban.change',
            entityType: 'player',
            entityId: nickname.trim().toLowerCase(),
            actorType: 'app_operator',
            actorId: actor,
            payload: {
              'action': 'ban',
              'nickname': nickname,
              'reason': reason,
              'duration_seconds': duration?.inSeconds,
              'online': online,
            },
            resultStatus: 'success',
          );
    } catch (error) {
      await ref
          .read(auditServiceProvider)
          .logEvent(
            eventType: 'ban.change',
            entityType: 'player',
            entityId: nickname.trim().toLowerCase(),
            actorType: 'app_operator',
            actorId: actor,
            payload: {
              'action': 'ban',
              'nickname': nickname,
              'reason': reason,
              'duration_seconds': duration?.inSeconds,
              'online': online,
              'error': error.toString(),
            },
            resultStatus: 'error',
          );
      rethrow;
    }
  }

  Future<void> unbanPlayer({
    required String nickname,
    String actor = 'app_operator',
  }) async {
    final runtime = ref.read(serverRuntimeProvider);
    final online = runtime.lifecycle == ServerLifecycleState.online;
    try {
      await _repository.unbanPlayer(
        nickname: nickname,
        removedBy: actor,
        pendingUnban: !online,
      );
      if (online) {
        await ref
            .read(serverRuntimeProvider.notifier)
            .sendCommand(_commands.pardon(nickname));
      }
      await ref
          .read(auditServiceProvider)
          .logEvent(
            eventType: 'ban.change',
            entityType: 'player',
            entityId: nickname.trim().toLowerCase(),
            actorType: 'app_operator',
            actorId: actor,
            payload: {
              'action': 'unban',
              'nickname': nickname,
              'online': online,
            },
            resultStatus: 'success',
          );
    } catch (error) {
      await ref
          .read(auditServiceProvider)
          .logEvent(
            eventType: 'ban.change',
            entityType: 'player',
            entityId: nickname.trim().toLowerCase(),
            actorType: 'app_operator',
            actorId: actor,
            payload: {
              'action': 'unban',
              'nickname': nickname,
              'online': online,
              'error': error.toString(),
            },
            resultStatus: 'error',
          );
      rethrow;
    }
  }

  Future<void> cancelPendingBan({
    required String nickname,
    String actor = 'app_operator',
  }) async {
    try {
      await _repository.cancelPendingBan(nickname: nickname, removedBy: actor);
      await ref
          .read(auditServiceProvider)
          .logEvent(
            eventType: 'ban.change',
            entityType: 'player',
            entityId: nickname.trim().toLowerCase(),
            actorType: 'app_operator',
            actorId: actor,
            payload: {
              'action': 'cancel_pending_ban',
              'nickname': nickname,
            },
            resultStatus: 'success',
          );
    } catch (error) {
      await ref
          .read(auditServiceProvider)
          .logEvent(
            eventType: 'ban.change',
            entityType: 'player',
            entityId: nickname.trim().toLowerCase(),
            actorType: 'app_operator',
            actorId: actor,
            payload: {
              'action': 'cancel_pending_ban',
              'nickname': nickname,
              'error': error.toString(),
            },
            resultStatus: 'error',
          );
      rethrow;
    }
  }

  Future<void> processBanSync() async {
    final runtime = ref.read(serverRuntimeProvider);
    final online = runtime.lifecycle == ServerLifecycleState.online;
    state = state.copyWith(syncing: true, clearError: true);
    try {
      await _repository.processExpiredBans(
        isServerOnline: online,
        onPardon: (nickname) async {
          await ref
              .read(serverRuntimeProvider.notifier)
              .sendCommand(_commands.pardon(nickname));
        },
      );
      await _repository.processPendingBan(
        isServerOnline: online,
        onBan: (nickname, reason) async {
          await ref
              .read(serverRuntimeProvider.notifier)
              .sendCommand(_commands.ban(nickname, reason: reason));
        },
      );
      await _repository.processPendingUnban(
        isServerOnline: online,
        onPardon: (nickname) async {
          await ref
              .read(serverRuntimeProvider.notifier)
              .sendCommand(_commands.pardon(nickname));
        },
      );
      state = state.copyWith(syncing: false);
    } catch (error) {
      state = state.copyWith(syncing: false, error: error.toString());
    }
  }
}
