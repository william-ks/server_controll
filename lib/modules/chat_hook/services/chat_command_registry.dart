import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/server_lifecycle_state.dart';
import '../../server/providers/server_runtime_provider.dart';
import '../models/chat_hook_command_request.dart';

enum ChatCommandPermissionPolicy { everyone, appAdmin }

extension ChatCommandPermissionPolicyX on ChatCommandPermissionPolicy {
  String get storageValue => switch (this) {
    ChatCommandPermissionPolicy.everyone => 'everyone',
    ChatCommandPermissionPolicy.appAdmin => 'app_admin',
  };
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
      description: 'Lista comandos disponíveis para o executor.',
      permission: ChatCommandPermissionPolicy.everyone,
      handler: _handleHelp,
    ),
    'status': ChatCommandDefinition(
      name: 'status',
      description: 'Mostra status atual do servidor.',
      permission: ChatCommandPermissionPolicy.everyone,
      handler: _handleStatus,
    ),
    'restart': ChatCommandDefinition(
      name: 'restart',
      description: 'Reinicia o servidor.',
      permission: ChatCommandPermissionPolicy.appAdmin,
      handler: _handleRestart,
    ),
  };

  ChatCommandDefinition? find(String command) {
    return _definitions[command.trim().toLowerCase()];
  }

  List<ChatCommandDefinition> allDefinitions() {
    return _definitions.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  List<ChatCommandDefinition> visibleFor({required bool isAppAdmin}) {
    return _definitions.values.where((definition) {
      if (definition.permission == ChatCommandPermissionPolicy.everyone) {
        return true;
      }
      return isAppAdmin;
    }).toList()..sort((a, b) => a.name.compareTo(b.name));
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
    final allowed = visibleFor(isAppAdmin: context.isAppAdmin);
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

  String _formatUptime(Duration value) {
    if (value.inHours > 0) {
      return '${value.inHours}h ${value.inMinutes.remainder(60)}m ${value.inSeconds.remainder(60)}s';
    }
    if (value.inMinutes > 0) {
      return '${value.inMinutes}m ${value.inSeconds.remainder(60)}s';
    }
    return '${value.inSeconds}s';
  }
}
