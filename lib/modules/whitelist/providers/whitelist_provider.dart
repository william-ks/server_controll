import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/server_lifecycle_state.dart';
import '../../../models/server_runtime_state.dart';
import '../../../modules/server/providers/server_runtime_provider.dart';
import '../models/whitelist_player.dart';
import '../repositories/whitelist_repository.dart';
import '../services/whitelist_sync_service.dart';

class WhitelistState {
  const WhitelistState({
    required this.players,
    required this.loading,
    this.error,
  });

  final List<WhitelistPlayer> players;
  final bool loading;
  final String? error;

  WhitelistState copyWith({
    List<WhitelistPlayer>? players,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return WhitelistState(
      players: players ?? this.players,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  factory WhitelistState.initial() => const WhitelistState(players: [], loading: false);
}

final whitelistRepositoryProvider = Provider<WhitelistRepository>((_) => WhitelistRepository());

final whitelistSyncServiceProvider = Provider<WhitelistSyncService>((ref) {
  return WhitelistSyncService(ref.read(whitelistRepositoryProvider));
});

final whitelistProvider = NotifierProvider<WhitelistNotifier, WhitelistState>(WhitelistNotifier.new);

class WhitelistNotifier extends Notifier<WhitelistState> {
  WhitelistRepository get _repository => ref.read(whitelistRepositoryProvider);
  WhitelistSyncService get _syncService => ref.read(whitelistSyncServiceProvider);

  @override
  WhitelistState build() {
    ref.listen<ServerRuntimeState>(serverRuntimeProvider, (previous, next) {
      final wasOnline = previous?.lifecycle == ServerLifecycleState.online;
      final isOnline = next.lifecycle == ServerLifecycleState.online;
      if (!wasOnline && isOnline) {
        unawaited(syncPending());
      }
    });

    Future<void>(() => load(initialLoad: true));
    return WhitelistState.initial();
  }

  Future<void> load({bool initialLoad = false}) async {
    if (initialLoad) {
      state = const WhitelistState(players: [], loading: true);
    } else {
      state = state.copyWith(loading: true, clearError: true);
    }

    try {
      final players = await _repository.getAll();
      final normalized = <WhitelistPlayer>[];
      for (final player in players) {
        final hasUuid = player.uuid != null && player.uuid!.trim().isNotEmpty;
        final shouldBePending = !hasUuid || !player.isAdded;
        if (player.isPending != shouldBePending) {
          final patched = player.copyWith(
            isPending: shouldBePending,
            isAdded: !shouldBePending,
            updatedAt: DateTime.now(),
          );
          await _repository.upsertByNickname(patched);
          normalized.add(patched);
        } else {
          normalized.add(player);
        }
      }
      state = state.copyWith(players: normalized, loading: false);
    } catch (error) {
      state = state.copyWith(loading: false, error: error.toString());
    }
  }

  Future<void> refreshAndSyncFromFile() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final players = await _syncService.syncFromServerFile();
      state = state.copyWith(players: players, loading: false);
    } catch (error) {
      state = state.copyWith(loading: false, error: error.toString());
    }
  }

  Future<void> syncPending() async {
    final runtime = ref.read(serverRuntimeProvider);
    await _syncService.syncPendingToServer(
      isServerOnline: runtime.lifecycle == ServerLifecycleState.online,
      sendCommand: ref.read(serverRuntimeProvider.notifier).sendCommand,
    );
    await load();
  }

  Future<void> savePlayer({
    int? id,
    required String nickname,
    String? uuid,
    String? iconPath,
  }) async {
    final now = DateTime.now();
    final hasUuid = uuid != null && uuid.trim().isNotEmpty;
    final player = WhitelistPlayer(
      id: id,
      nickname: nickname.trim(),
      uuid: hasUuid ? uuid.trim() : null,
      iconPath: iconPath,
      isPending: !hasUuid,
      isAdded: hasUuid,
      createdAt: now,
      updatedAt: now,
    );

    if (id == null) {
      await _repository.insert(player);
    } else {
      await _repository.update(player);
    }

    await load();
  }

  Future<void> removePlayer(int id) async {
    await _repository.delete(id);
    await load();
  }

  Future<String?> pickIconAndSave(String nickname) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
    );

    final sourcePath = result?.files.single.path;
    if (sourcePath == null) {
      return null;
    }

    return _syncService.persistIcon(nickname: nickname, sourcePath: sourcePath);
  }
}
