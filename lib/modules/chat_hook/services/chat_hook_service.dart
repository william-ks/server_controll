import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audit/services/audit_service.dart';
import '../../console/providers/console_provider.dart';
import '../../players/providers/player_permissions_provider.dart';
import '../../server/providers/server_runtime_provider.dart';
import '../../server/services/minecraft_command_provider.dart';
import '../repositories/chat_hook_history_repository.dart';
import 'chat_command_registry.dart';
import 'chat_hook_parser.dart';

final chatHookServiceProvider = Provider<ChatHookService>(
  (ref) => ChatHookService(ref),
);

class ChatHookService {
  ChatHookService(this._ref);

  static const _commands = MinecraftCommandProvider.vanilla;
  final Ref _ref;

  Future<void> processStdoutLine(String line) async {
    final request = ChatHookParser.parse(line);
    if (request == null) {
      return;
    }

    final permissionsRepo = _ref.read(playerPermissionsRepositoryProvider);
    final status = await permissionsRepo.getStatusForNickname(request.player);
    final isAppAdmin = status.isAppAdmin;

    final registry = _ref.read(chatCommandRegistryProvider);
    final definition = await registry.find(request.command);
    if (definition == null) {
      const message = 'Comando desconhecido. Use <server> help.';
      await _sendResponse(message);
      await _logAudit(
        player: request.player,
        command: request.command,
        args: request.args,
        permissionPolicy: 'unknown',
        resultStatus: 'unknown_command',
        resultMessage: message,
      );
      await _logHistory(
        player: request.player,
        rawCommand: request.raw,
        parsedCommand: request.command,
        args: request.args,
        permissionApplied: 'unknown',
        resultStatus: 'unknown_command',
        resultMessage: message,
      );
      return;
    }

    final allowed = registry.isAllowed(
      definition: definition,
      isAppAdmin: isAppAdmin,
    );
    if (!allowed) {
      const message =
          'Você não tem permissão para esse comando do hook <server>.';
      await _sendResponse(message);
      await _logAudit(
        player: request.player,
        command: definition.name,
        args: request.args,
        permissionPolicy: definition.permission.storageValue,
        resultStatus: 'denied',
        resultMessage: message,
      );
      await _logHistory(
        player: request.player,
        rawCommand: request.raw,
        parsedCommand: definition.name,
        args: request.args,
        permissionApplied: definition.permission.storageValue,
        resultStatus: 'denied',
        resultMessage: message,
      );
      return;
    }

    try {
      final result = await definition.handler(
        ChatCommandExecutionContext(
          ref: _ref,
          request: request,
          isAppAdmin: isAppAdmin,
        ),
      );
      await _sendResponse(result.message);
      await _logAudit(
        player: request.player,
        command: definition.name,
        args: request.args,
        permissionPolicy: definition.permission.storageValue,
        resultStatus: result.success ? 'success' : 'error',
        resultMessage: result.message,
      );
      await _logHistory(
        player: request.player,
        rawCommand: request.raw,
        parsedCommand: definition.name,
        args: request.args,
        permissionApplied: definition.permission.storageValue,
        resultStatus: result.success ? 'success' : 'error',
        resultMessage: result.message,
      );
    } catch (error) {
      final message = error.toString().replaceFirst('Bad state: ', '').trim();
      await _sendResponse('Falha ao executar comando: $message');
      await _logAudit(
        player: request.player,
        command: definition.name,
        args: request.args,
        permissionPolicy: definition.permission.storageValue,
        resultStatus: 'error',
        resultMessage: message,
      );
      await _logHistory(
        player: request.player,
        rawCommand: request.raw,
        parsedCommand: definition.name,
        args: request.args,
        permissionApplied: definition.permission.storageValue,
        resultStatus: 'error',
        resultMessage: message,
      );
    }
  }

  Future<void> _sendResponse(String message) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      return;
    }
    _ref
        .read(consoleProvider.notifier)
        .appendSystemMessage('[CHAT HOOK] $trimmed');
    await _ref
        .read(serverRuntimeProvider.notifier)
        .sendCommand(_commands.say(trimmed, prefix: '[SERVER 🤖]'));
  }

  Future<void> _logHistory({
    required String player,
    required String rawCommand,
    required String? parsedCommand,
    required List<String> args,
    required String permissionApplied,
    required String resultStatus,
    required String resultMessage,
  }) async {
    await _ref
        .read(chatHookHistoryRepositoryProvider)
        .logExecution(
          player: player,
          rawCommand: rawCommand,
          parsedCommand: parsedCommand,
          args: args,
          permissionApplied: permissionApplied,
          resultStatus: resultStatus,
          resultMessage: resultMessage,
        );
  }

  Future<void> _logAudit({
    required String player,
    required String command,
    required List<String> args,
    required String permissionPolicy,
    required String resultStatus,
    required String resultMessage,
  }) async {
    await _ref
        .read(auditServiceProvider)
        .logEvent(
          eventType: 'chat_hook.command',
          entityType: 'chat_hook',
          entityId: command,
          actorType: 'player',
          actorId: player,
          payload: {
            'command': command,
            'args': args,
            'permission_policy': permissionPolicy,
            'result_message': resultMessage,
          },
          resultStatus: resultStatus,
        );
  }
}
