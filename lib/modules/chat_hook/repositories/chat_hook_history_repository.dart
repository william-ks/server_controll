import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';

final chatHookHistoryRepositoryProvider = Provider<ChatHookHistoryRepository>(
  (_) => ChatHookHistoryRepository(),
);

class ChatHookHistoryRepository {
  Future<void> logExecution({
    required String player,
    required String rawCommand,
    required String? parsedCommand,
    required List<String> args,
    required String permissionApplied,
    required String resultStatus,
    String? resultMessage,
  }) async {
    final db = await AppDatabase.instance.database;
    await db.insert('chat_hook_history', {
      'player': player.trim(),
      'raw_command': rawCommand.trim(),
      'parsed_command': parsedCommand?.trim(),
      'parsed_args': jsonEncode(args),
      'permission_applied': permissionApplied.trim(),
      'result_status': resultStatus.trim(),
      'result_message': resultMessage?.trim(),
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}
