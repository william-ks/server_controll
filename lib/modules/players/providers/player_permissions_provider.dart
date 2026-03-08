import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/server_lifecycle_state.dart';
import '../../../models/server_runtime_state.dart';
import '../../server/providers/server_runtime_provider.dart';
import '../../server/services/minecraft_command_provider.dart';
import '../models/player_permission_status.dart';
import '../repositories/player_permissions_repository.dart';

class PlayerPermissionsState {
  const PlayerPermissionsState({
    required this.loading,
    required this.syncing,
    required this.statusByNickname,
    this.error,
  });

  final bool loading;
  final bool syncing;
  final Map<String, PlayerPermissionStatus> statusByNickname;
  final String? error;

  PlayerPermissionsState copyWith({
    bool? loading,
    bool? syncing,
    Map<String, PlayerPermissionStatus>? statusByNickname,
    String? error,
    bool clearError = false,
  }) {
    return PlayerPermissionsState(
      loading: loading ?? this.loading,
      syncing: syncing ?? this.syncing,
      statusByNickname: statusByNickname ?? this.statusByNickname,
      error: clearError ? null : (error ?? this.error),
    );
  }

  factory PlayerPermissionsState.initial() {
    return const PlayerPermissionsState(
      loading: false,
      syncing: false,
      statusByNickname: {},
    );
  }
}

final playerPermissionsRepositoryProvider =
    Provider<PlayerPermissionsRepository>((_) => PlayerPermissionsRepository());

final playerPermissionsProvider =
    NotifierProvider<PlayerPermissionsNotifier, PlayerPermissionsState>(
      PlayerPermissionsNotifier.new,
    );

class PlayerPermissionsNotifier extends Notifier<PlayerPermissionsState> {
  static const _commands = MinecraftCommandProvider.vanilla;
  final Set<String> _loadedNicknames = <String>{};

  PlayerPermissionsRepository get _repository =>
      ref.read(playerPermissionsRepositoryProvider);

  @override
  PlayerPermissionsState build() {
    ref.listen<ServerRuntimeState>(serverRuntimeProvider, (previous, next) {
      final becameOnline =
          previous?.lifecycle != ServerLifecycleState.online &&
          next.lifecycle == ServerLifecycleState.online;
      if (becameOnline) {
        unawaited(processPendingActionsIfOnline());
      }
    });
    Future<void>(() => processPendingActionsIfOnline());
    return PlayerPermissionsState.initial();
  }

  Future<void> syncWhitelist(List<String> nicknames) async {
    await _repository.syncWhitelistFlags(nicknames);
    await loadForNicknames(nicknames);
  }

  Future<void> loadForNicknames(List<String> nicknames) async {
    final normalized = <String>{
      for (final nickname in nicknames)
        if (nickname.trim().isNotEmpty) nickname.trim().toLowerCase(),
    };
    if (normalized.isEmpty) {
      state = state.copyWith(statusByNickname: {});
      _loadedNicknames.clear();
      return;
    }

    state = state.copyWith(loading: true, clearError: true);
    try {
      final statuses = await _repository.listStatusesByNicknames(
        normalized.toList(),
      );
      _loadedNicknames
        ..clear()
        ..addAll(normalized);
      state = state.copyWith(
        loading: false,
        statusByNickname: statuses,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(loading: false, error: error.toString());
    }
  }

  Future<void> toggleAppAdmin(String nickname, bool enabled) async {
    final runtime = ref.read(serverRuntimeProvider);
    final key = nickname.trim().toLowerCase();
    final current = state.statusByNickname[key];

    await _repository.setAppAdmin(nickname, enabled);
    if (!enabled && (current?.isOp ?? false)) {
      if (runtime.lifecycle == ServerLifecycleState.online) {
        await ref
            .read(serverRuntimeProvider.notifier)
            .sendCommand(_commands.deop(nickname));
      } else {
        await _repository.enqueuePendingOpAction(
          nickname: nickname,
          promote: false,
        );
      }
    }
    await _reloadLoaded();
  }

  Future<void> toggleOp(String nickname, bool enabled) async {
    final runtime = ref.read(serverRuntimeProvider);
    await _repository.setOpStatus(nickname, enabled);
    if (runtime.lifecycle == ServerLifecycleState.online) {
      await ref
          .read(serverRuntimeProvider.notifier)
          .sendCommand(
            enabled ? _commands.op(nickname) : _commands.deop(nickname),
          );
    } else {
      await _repository.enqueuePendingOpAction(
        nickname: nickname,
        promote: enabled,
      );
    }
    await _reloadLoaded();
  }

  Future<void> processPendingActionsIfOnline() async {
    final runtime = ref.read(serverRuntimeProvider);
    if (runtime.lifecycle != ServerLifecycleState.online) {
      return;
    }

    state = state.copyWith(syncing: true, clearError: true);
    try {
      final pending = await _repository.loadPendingActions();
      for (final action in pending) {
        try {
          if (action.actionType == 'op') {
            await ref
                .read(serverRuntimeProvider.notifier)
                .sendCommand(_commands.op(action.nickname));
          } else {
            await ref
                .read(serverRuntimeProvider.notifier)
                .sendCommand(_commands.deop(action.nickname));
          }
          await _repository.markPendingApplied(action.id);
        } catch (error) {
          await _repository.markPendingFailed(action.id, error.toString());
        }
      }
      await _reloadLoaded();
      state = state.copyWith(syncing: false);
    } catch (error) {
      state = state.copyWith(syncing: false, error: error.toString());
    }
  }

  Future<void> _reloadLoaded() async {
    if (_loadedNicknames.isEmpty) return;
    await loadForNicknames(_loadedNicknames.toList());
  }
}
