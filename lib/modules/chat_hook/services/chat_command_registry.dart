import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/server_lifecycle_state.dart';
import '../../players/repositories/player_playtime_repository.dart';
import '../../server/providers/server_runtime_provider.dart';
import '../models/chat_hook_command_request.dart';
import '../repositories/chat_hook_command_settings_repository.dart';

enum ChatCommandPermissionPolicy { everyone, appAdmin }

extension ChatCommandPermissionPolicyX on ChatCommandPermissionPolicy {
  String get storageValue => switch (this) {
    ChatCommandPermissionPolicy.everyone => 'everyone',
    ChatCommandPermissionPolicy.appAdmin => 'app_admin',
  };

  String get label => switch (this) {
    ChatCommandPermissionPolicy.everyone => 'Todos',
    ChatCommandPermissionPolicy.appAdmin => 'Somente admin',
  };

  static ChatCommandPermissionPolicy? fromStorageValue(String? raw) {
    return switch (raw?.trim().toLowerCase()) {
      'everyone' => ChatCommandPermissionPolicy.everyone,
      'app_admin' => ChatCommandPermissionPolicy.appAdmin,
      _ => null,
    };
  }
}

class ChatCommandExecutionContext {
  const ChatCommandExecutionContext({
    required this.ref,
    required this.request,
    required this.isAppAdmin,
  });

  final Ref ref;
  final ChatHookCommandRequest request;
  final bool isAppAdmin;
}

class ChatCommandExecutionResult {
  const ChatCommandExecutionResult({
    required this.success,
    required this.message,
  });

  final bool success;
  final String message;
}

typedef ChatCommandHandler =
    Future<ChatCommandExecutionResult> Function(ChatCommandExecutionContext);

class ChatCommandDefinition {
  const ChatCommandDefinition({
    required this.name,
    required this.description,
    required this.permission,
    required this.handler,
  });

  final String name;
  final String description;
  final ChatCommandPermissionPolicy permission;
  final ChatCommandHandler handler;

  ChatCommandDefinition copyWith({
    String? name,
    String? description,
    ChatCommandPermissionPolicy? permission,
    ChatCommandHandler? handler,
  }) {
    return ChatCommandDefinition(
      name: name ?? this.name,
      description: description ?? this.description,
      permission: permission ?? this.permission,
      handler: handler ?? this.handler,
    );
  }
}

final chatCommandRegistryProvider = Provider<ChatCommandRegistry>(
  (ref) => ChatCommandRegistry(ref),
);

class ChatCommandRegistry {
  ChatCommandRegistry(this._ref);

  final Ref _ref;

  late final Map<String, ChatCommandDefinition> _definitions = {
    'help': ChatCommandDefinition(
      name: 'help',
      description:
          'Exibe todos os comandos disponíveis para quem executou o hook, com descrição resumida.',
      permission: ChatCommandPermissionPolicy.everyone,
      handler: _handleHelp,
    ),
    'status': ChatCommandDefinition(
      name: 'status',
      description:
          'Mostra o status atual do servidor, jogadores online e uptime.',
      permission: ChatCommandPermissionPolicy.everyone,
      handler: _handleStatus,
    ),
    'restart': ChatCommandDefinition(
      name: 'restart',
      description: 'Solicita o reinício imediato do servidor.',
      permission: ChatCommandPermissionPolicy.appAdmin,
      handler: _handleRestart,
    ),
    'ranking': ChatCommandDefinition(
      name: 'ranking',
      description:
          'Lista o top 5 jogadores com mais horas totais de gameplay registradas.',
      permission: ChatCommandPermissionPolicy.everyone,
      handler: _handleRanking,
    ),
  };

  Future<ChatCommandDefinition?> find(String command) async {
    final base = _definitions[command.trim().toLowerCase()];
    if (base == null) {
      return null;
    }
    final permission = await _ref
        .read(chatHookCommandSettingsRepositoryProvider)
        .getPermission(command: base.name, fallback: base.permission);
    return base.copyWith(permission: permission);
  }

  Future<List<ChatCommandDefinition>> allDefinitions() async {
    final resolved = <ChatCommandDefinition>[];
    final repo = _ref.read(chatHookCommandSettingsRepositoryProvider);
    final items = _definitions.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    for (final item in items) {
      final permission = await repo.getPermission(
        command: item.name,
        fallback: item.permission,
      );
      resolved.add(item.copyWith(permission: permission));
    }
    return resolved;
  }

  Future<void> setPermission(
    String command,
    ChatCommandPermissionPolicy permission,
  ) {
    return _ref
        .read(chatHookCommandSettingsRepositoryProvider)
        .setPermission(command: command, permission: permission);
  }

  Future<List<ChatCommandDefinition>> visibleFor({
    required bool isAppAdmin,
  }) async {
    final resolved = await allDefinitions();
    return resolved.where((definition) {
      if (definition.permission == ChatCommandPermissionPolicy.everyone) {
        return true;
      }
      return isAppAdmin;
    }).toList();
  }

  bool isAllowed({
    required ChatCommandDefinition definition,
    required bool isAppAdmin,
  }) {
    if (definition.permission == ChatCommandPermissionPolicy.everyone) {
      return true;
    }
    return isAppAdmin;
  }

  Future<ChatCommandExecutionResult> _handleHelp(
    ChatCommandExecutionContext context,
  ) async {
    final allowed = await visibleFor(isAppAdmin: context.isAppAdmin);
    final summary = allowed
        .map((item) => '${item.name}: ${item.description}')
        .join(' | ');
    return ChatCommandExecutionResult(success: true, message: summary);
  }

  Future<ChatCommandExecutionResult> _handleStatus(
    ChatCommandExecutionContext context,
  ) async {
    final runtime = _ref.read(serverRuntimeProvider);
    final lifecycle = switch (runtime.lifecycle) {
      ServerLifecycleState.offline => 'offline',
      ServerLifecycleState.starting => 'starting',
      ServerLifecycleState.online => 'online',
      ServerLifecycleState.stopping => 'stopping',
      ServerLifecycleState.restarting => 'restarting',
      ServerLifecycleState.error => 'error',
    };
    final uptime = _formatUptime(runtime.uptime);
    return ChatCommandExecutionResult(
      success: true,
      message:
          'Status: $lifecycle | Players: ${runtime.activePlayers} | Uptime: $uptime',
    );
  }

  Future<ChatCommandExecutionResult> _handleRestart(
    ChatCommandExecutionContext context,
  ) async {
    final runtime = _ref.read(serverRuntimeProvider);
    if (runtime.lifecycle != ServerLifecycleState.online) {
      return const ChatCommandExecutionResult(
        success: false,
        message: 'Não foi possível reiniciar: servidor não está online.',
      );
    }

    await _ref.read(serverRuntimeProvider.notifier).restartServer();
    return const ChatCommandExecutionResult(
      success: true,
      message: 'Reinício do servidor solicitado com sucesso.',
    );
  }

  Future<ChatCommandExecutionResult> _handleRanking(
    ChatCommandExecutionContext context,
  ) async {
    final ranking = await PlayerPlaytimeRepository().fetchRanking();
    final topFive = ranking.where((item) => item.totalSeconds > 0).take(5).toList();
    if (topFive.isEmpty) {
      return const ChatCommandExecutionResult(
        success: true,
        message: 'Ranking indisponível no momento: ainda não há horas registradas.',
      );
    }

    final summary = topFive
        .asMap()
        .entries
        .map(
          (entry) =>
              '${entry.key + 1}. ${entry.value.nickname} - ${_formatPlaytime(entry.value.totalSeconds)}',
        )
        .join(' | ');
    return ChatCommandExecutionResult(
      success: true,
      message: 'Top 5 tempo de jogo: $summary',
    );
  }

  String _formatUptime(Duration value) {
    if (value.inHours > 0) {
      return '${value.inHours}h ${value.inMinutes.remainder(60)}m ${value.inSeconds.remainder(60)}s';
    }
    if (value.inMinutes > 0) {
      return '${value.inMinutes}m ${value.inSeconds.remainder(60)}s';
    }
    return '${value.inSeconds}s';
  }

  String _formatPlaytime(int totalSeconds) {
    final duration = Duration(seconds: totalSeconds);
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    }
    if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
    }
    return '${duration.inSeconds}s';
  }
}
