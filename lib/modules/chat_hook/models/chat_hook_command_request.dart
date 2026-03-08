class ChatHookCommandRequest {
  const ChatHookCommandRequest({
    required this.raw,
    required this.player,
    required this.command,
    required this.args,
  });

  final String raw;
  final String player;
  final String command;
  final List<String> args;
}
