import '../models/chat_hook_command_request.dart';

class ChatHookParser {
  static final RegExp _playerChatLine = RegExp(r'\]:\s<([^>]+)>\s*(.+)$');

  static ChatHookCommandRequest? parse(String stdoutLine) {
    final match = _playerChatLine.firstMatch(stdoutLine);
    if (match == null) {
      return null;
    }

    final player = (match.group(1) ?? '').trim();
    final rawMessage = (match.group(2) ?? '').trim();
    if (player.isEmpty || rawMessage.isEmpty) {
      return null;
    }

    final lowerRaw = rawMessage.toLowerCase();
    const prefix = '<server>';
    if (!lowerRaw.startsWith(prefix)) {
      return null;
    }

    final commandChunk = rawMessage.substring(prefix.length).trim();
    if (commandChunk.isEmpty) {
      return ChatHookCommandRequest(
        raw: rawMessage,
        player: player,
        command: 'help',
        args: const [],
      );
    }

    final tokens = commandChunk
        .split(RegExp(r'\s+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    if (tokens.isEmpty) {
      return ChatHookCommandRequest(
        raw: rawMessage,
        player: player,
        command: 'help',
        args: const [],
      );
    }

    return ChatHookCommandRequest(
      raw: rawMessage,
      player: player,
      command: tokens.first.toLowerCase(),
      args: tokens.skip(1).map((item) => item.toLowerCase()).toList(),
    );
  }
}
