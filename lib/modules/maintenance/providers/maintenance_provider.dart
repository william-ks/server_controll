import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/server_lifecycle_state.dart';
import '../../../models/server_runtime_state.dart';
import '../../config/providers/config_files_provider.dart';
import '../../server/providers/server_runtime_provider.dart';
import '../models/maintenance_defaults.dart';
import '../models/maintenance_mode.dart';
import '../models/maintenance_snapshot.dart';
import '../services/maintenance_service.dart';

class MaintenanceState {
  const MaintenanceState({
    required this.loading,
    required this.saving,
    required this.snapshot,
    required this.defaults,
    this.countdownRemainingSeconds = 0,
    this.error,
  });

  final bool loading;
  final bool saving;
  final MaintenanceSnapshot snapshot;
  final MaintenanceDefaults defaults;
  final int countdownRemainingSeconds;
  final String? error;

  MaintenanceState copyWith({
    bool? loading,
    bool? saving,
    MaintenanceSnapshot? snapshot,
    MaintenanceDefaults? defaults,
    int? countdownRemainingSeconds,
    String? error,
    bool clearError = false,
  }) {
    return MaintenanceState(
      loading: loading ?? this.loading,
      saving: saving ?? this.saving,
      snapshot: snapshot ?? this.snapshot,
      defaults: defaults ?? this.defaults,
      countdownRemainingSeconds:
          countdownRemainingSeconds ?? this.countdownRemainingSeconds,
      error: clearError ? null : (error ?? this.error),
    );
  }

  factory MaintenanceState.initial() {
    return MaintenanceState(
      loading: false,
      saving: false,
      snapshot: MaintenanceSnapshot.inactive(),
      defaults: MaintenanceDefaults.defaults(),
    );
  }
}

final maintenanceServiceProvider = Provider<MaintenanceService>(
  (_) => MaintenanceService(),
);

final maintenanceProvider =
    NotifierProvider<MaintenanceNotifier, MaintenanceState>(
      MaintenanceNotifier.new,
    );

class MaintenanceNotifier extends Notifier<MaintenanceState> {
  MaintenanceService get _service => ref.read(maintenanceServiceProvider);

  Timer? _countdownTimer;
  final Map<String, DateTime> _lastKickByPlayer = {};

  @override
  MaintenanceState build() {
    ref.listen<ServerRuntimeState>(serverRuntimeProvider, (previous, next) {
      unawaited(_onRuntimeChanged(previous, next));
    });

    Future<void>(() async {
      await refresh();
      await _hydrateScheduledActivation();
      await _enforceAccess();
    });

    ref.onDispose(() {
      _countdownTimer?.cancel();
    });

    return MaintenanceState.initial();
  }

  Future<void> refresh() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final snapshot = await _service.loadSnapshot();
      final defaults = await _service.loadDefaults();
      state = state.copyWith(
        loading: false,
        snapshot: snapshot,
        defaults: defaults,
      );
    } catch (error) {
      state = state.copyWith(loading: false, error: error.toString());
    }
  }

  Future<void> saveDefaults(MaintenanceDefaults defaults) async {
    state = state.copyWith(saving: true, clearError: true);
    try {
      await _service.saveDefaults(defaults);
      state = state.copyWith(defaults: defaults, saving: false);
    } catch (error) {
      state = state.copyWith(saving: false, error: error.toString());
      rethrow;
    }
  }

  Future<void> activateNow({
    required MaintenanceMode mode,
    int countdownSeconds = 0,
  }) async {
    if (countdownSeconds <= 0) {
      await _activateInternal(mode);
      return;
    }

    final startsAt = DateTime.now().add(Duration(seconds: countdownSeconds));
    await _service.saveScheduledState(
      mode: mode,
      startsAt: startsAt,
      countdownSeconds: countdownSeconds,
    );
    await refresh();
    await _startCountdown(mode, startsAt);
  }

  Future<void> deactivate() async {
    _countdownTimer?.cancel();
    state = state.copyWith(saving: true, clearError: true);
    try {
      final serverPath = ref.read(configFilesProvider).serverPath.trim();
      final snapshot = await _service.deactivate(serverPath: serverPath);
      state = state.copyWith(
        saving: false,
        snapshot: snapshot,
        countdownRemainingSeconds: 0,
      );
      await _service.sendMaintenanceMessage(
        _sendCommand,
        'Modo de manutenção desativado. Acesso normal restaurado.',
      );
    } catch (error) {
      state = state.copyWith(saving: false, error: error.toString());
      rethrow;
    }
  }

  Future<void> _hydrateScheduledActivation() async {
    final snapshot = state.snapshot;
    if (snapshot.isActive || snapshot.startsAt == null) {
      return;
    }
    final startsAt = snapshot.startsAt!;
    if (startsAt.isBefore(DateTime.now())) {
      await _activateInternal(snapshot.mode);
      return;
    }
    await _startCountdown(snapshot.mode, startsAt);
  }

  Future<void> _startCountdown(MaintenanceMode mode, DateTime startsAt) async {
    _countdownTimer?.cancel();
    await _sendCountdownMilestoneIfNeeded(
      startsAt.difference(DateTime.now()).inSeconds,
    );

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final remaining = startsAt.difference(DateTime.now()).inSeconds;
      if (remaining <= 0) {
        timer.cancel();
        state = state.copyWith(countdownRemainingSeconds: 0);
        await _activateInternal(mode);
        return;
      }

      state = state.copyWith(countdownRemainingSeconds: remaining);
      await _sendCountdownMilestoneIfNeeded(remaining);
    });
  }

  Future<void> _sendCountdownMilestoneIfNeeded(int remaining) async {
    if (remaining != 60 && remaining != 30 && remaining != 10) {
      return;
    }
    await _service.sendMaintenanceMessage(
      _sendCommand,
      'Modo de manutenção em $remaining segundo(s).',
    );
  }

  Future<void> _activateInternal(MaintenanceMode mode) async {
    state = state.copyWith(saving: true, clearError: true);
    try {
      final serverPath = ref.read(configFilesProvider).serverPath.trim();
      final snapshot = await _service.activate(
        mode: mode,
        serverPath: serverPath,
      );
      state = state.copyWith(
        saving: false,
        snapshot: snapshot,
        countdownRemainingSeconds: 0,
      );
      final label = mode == MaintenanceMode.total
          ? 'total'
          : 'somente admins do app';
      await _service.sendMaintenanceMessage(
        _sendCommand,
        'Modo de manutenção ativo ($label).',
      );
      await _enforceAccess();
    } catch (error) {
      state = state.copyWith(saving: false, error: error.toString());
      rethrow;
    }
  }

  Future<void> _onRuntimeChanged(
    ServerRuntimeState? previous,
    ServerRuntimeState next,
  ) async {
    if (!state.snapshot.isActive) {
      return;
    }
    if (next.lifecycle != ServerLifecycleState.online) {
      return;
    }

    final previousPlayers = <String>{
      for (final name in previous?.onlinePlayers ?? const <String>[])
        if (name.trim().isNotEmpty) name.trim().toLowerCase(),
    };
    final joinedPlayers = <String>[
      for (final name in next.onlinePlayers)
        if (name.trim().isNotEmpty &&
            !previousPlayers.contains(name.trim().toLowerCase()))
          name.trim(),
    ];

    if (joinedPlayers.isEmpty) {
      return;
    }

    for (final nickname in joinedPlayers) {
      final allowed = await _service.isPlayerAllowed(
        mode: state.snapshot.mode,
        nickname: nickname,
      );
      if (!allowed) {
        await _kickUnauthorized(nickname);
      }
    }
  }

  Future<void> _enforceAccess() async {
    if (!state.snapshot.isActive) {
      return;
    }
    final runtime = ref.read(serverRuntimeProvider);
    if (runtime.lifecycle != ServerLifecycleState.online) {
      return;
    }

    final blocked = await _service.resolveUnauthorizedPlayers(
      mode: state.snapshot.mode,
      onlinePlayers: runtime.onlinePlayers,
    );
    for (final nickname in blocked) {
      await _kickUnauthorized(nickname);
    }
  }

  Future<void> _kickUnauthorized(String nickname) async {
    final key = nickname.toLowerCase();
    final lastKick = _lastKickByPlayer[key];
    if (lastKick != null && DateTime.now().difference(lastKick).inSeconds < 8) {
      return;
    }
    _lastKickByPlayer[key] = DateTime.now();
    final reason = state.snapshot.mode == MaintenanceMode.total
        ? '[SERVER 🤖] Servidor em manutenção.'
        : '[SERVER 🤖] Acesso permitido apenas para admins do app.';
    await _service.kickPlayer(_sendCommand, nickname: nickname, reason: reason);
  }

  Future<void> _sendCommand(String command) async {
    await ref.read(serverRuntimeProvider.notifier).sendCommand(command);
  }
}
