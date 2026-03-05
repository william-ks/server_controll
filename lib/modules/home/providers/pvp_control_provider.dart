import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../../../models/server_lifecycle_state.dart';
import '../../../models/server_runtime_state.dart';
import '../../config/providers/config_files_provider.dart';
import '../../config/services/server_properties_service.dart';
import '../../server/providers/server_runtime_provider.dart';
import '../../server/services/minecraft_command_provider.dart';

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
  final ServerPropertiesService _propertiesService = ServerPropertiesService();
  static const _commands = MinecraftCommandProvider.vanilla;
  int? _lastAppliedReadyAtMillis;

  @override
  PvpControlState build() {
    ref.listen<ServerRuntimeState>(serverRuntimeProvider, (previous, next) {
      final becameOnline =
          previous?.lifecycle != ServerLifecycleState.online &&
          next.lifecycle == ServerLifecycleState.online;
      final readyAt = next.readyAt;
      final readyMark = readyAt?.millisecondsSinceEpoch;
      if (!becameOnline || readyMark == null) {
        return;
      }
      if (_lastAppliedReadyAtMillis == readyMark) {
        return;
      }
      _lastAppliedReadyAtMillis = readyMark;
      Future<void>(() => _applyRuntimeDesiredState());
    });

    Future<void>(() => _bootstrapConsistency());
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
      final command = _commands.gamerulePvp(desiredPvpEnabled);
      await ref.read(serverRuntimeProvider.notifier).sendCommand(command);
      await AppDatabase.instance.setSetting(
        'pvp_enabled',
        desiredPvpEnabled ? '1' : '0',
      );
      await AppDatabase.instance.setSetting(
        'prop_pvp',
        desiredPvpEnabled ? '1' : '0',
      );

      final serverPath = ref.read(configFilesProvider).serverPath.trim();
      if (serverPath.isNotEmpty) {
        await _propertiesService.setPvpValue(
          serverPath: serverPath,
          enabled: desiredPvpEnabled,
        );
      }
      state = state.copyWith(updating: false);
      return true;
    } catch (error) {
      await AppDatabase.instance.setSetting(
        'pvp_enabled',
        previous ? '1' : '0',
      );
      await AppDatabase.instance.setSetting('prop_pvp', previous ? '1' : '0');
      final runtimeNow = ref.read(serverRuntimeProvider);
      if (runtimeNow.lifecycle == ServerLifecycleState.online) {
        final revertCommand = _commands.gamerulePvp(previous);
        await ref
            .read(serverRuntimeProvider.notifier)
            .sendCommand(revertCommand);
      }
      state = state.copyWith(
        enabled: previous,
        updating: false,
        errorMessage: error.toString(),
      );
      return false;
    }
  }

  Future<void> _bootstrapConsistency() async {
    final serverPath = ref.read(configFilesProvider).serverPath.trim();
    final dbRaw = await AppDatabase.instance.getSetting('pvp_enabled');
    final propRaw = await AppDatabase.instance.getSetting('prop_pvp');
    bool? filePvp;
    if (serverPath.isNotEmpty) {
      final fromFile = await _propertiesService.loadFromFile(serverPath);
      filePvp = fromFile?.pvp;
    }

    final desired = dbRaw != null
        ? dbRaw == '1'
        : (propRaw != null ? propRaw == '1' : (filePvp ?? true));

    await AppDatabase.instance.setSetting('pvp_enabled', desired ? '1' : '0');
    await AppDatabase.instance.setSetting('prop_pvp', desired ? '1' : '0');

    if (serverPath.isNotEmpty && filePvp != null && filePvp != desired) {
      await _propertiesService.setPvpValue(
        serverPath: serverPath,
        enabled: desired,
      );
    }

    state = state.copyWith(enabled: desired);
  }

  Future<void> _applyRuntimeDesiredState() async {
    final runtime = ref.read(serverRuntimeProvider);
    if (runtime.lifecycle != ServerLifecycleState.online) {
      return;
    }
    final command = _commands.gamerulePvp(state.enabled);
    await ref.read(serverRuntimeProvider.notifier).sendCommand(command);
  }
}
