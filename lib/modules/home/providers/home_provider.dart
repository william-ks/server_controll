import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../modules/server/providers/server_runtime_provider.dart';

final homeActionsProvider = Provider<HomeActions>((ref) {
  return HomeActions(ref);
});

class HomeActions {
  HomeActions(this._ref);

  final Ref _ref;

  Future<void> startServer() => _ref.read(serverRuntimeProvider.notifier).startServer();

  Future<void> stopServer() => _ref.read(serverRuntimeProvider.notifier).stopServer();

  Future<void> restartServer() => _ref.read(serverRuntimeProvider.notifier).restartServer();

  Future<void> requestPlayers() => _ref.read(serverRuntimeProvider.notifier).requestOnlinePlayers();

  Future<void> sendCommand(String command) => _ref.read(serverRuntimeProvider.notifier).sendCommand(command);
}
