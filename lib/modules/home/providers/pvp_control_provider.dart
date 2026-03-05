import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/server_lifecycle_state.dart';
import '../../server/providers/server_runtime_provider.dart';

class PvpControlState {
  const PvpControlState({
    required this.enabled,
    required this.updating,
    this.errorMessage,
  });

  final bool enabled;
  final bool updating;
  final String? errorMessage;

  PvpControlState copyWith({
    bool? enabled,
    bool? updating,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PvpControlState(
      enabled: enabled ?? this.enabled,
      updating: updating ?? this.updating,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  factory PvpControlState.initial() {
    return const PvpControlState(enabled: true, updating: false);
  }
}

final pvpControlProvider =
    NotifierProvider<PvpControlNotifier, PvpControlState>(
      PvpControlNotifier.new,
    );

class PvpControlNotifier extends Notifier<PvpControlState> {
  @override
  PvpControlState build() {
    return PvpControlState.initial();
  }

  Future<bool> setDesiredWithRuntime(bool desiredPvpEnabled) async {
    final runtime = ref.read(serverRuntimeProvider);
    if (runtime.lifecycle != ServerLifecycleState.online) {
      return false;
    }

    final previous = state.enabled;
    state = state.copyWith(
      enabled: desiredPvpEnabled,
      updating: true,
      clearError: true,
    );

    try {
      final command = desiredPvpEnabled
          ? '/gamerule pvp true'
          : '/gamerule pvp false';
      await ref.read(serverRuntimeProvider.notifier).sendCommand(command);
      state = state.copyWith(updating: false);
      return true;
    } catch (error) {
      state = state.copyWith(
        enabled: previous,
        updating: false,
        errorMessage: error.toString(),
      );
      return false;
    }
  }
}
