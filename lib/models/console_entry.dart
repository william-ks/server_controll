enum ConsoleEntrySource { server, user, system }

class ConsoleEntry {
  const ConsoleEntry({
    required this.source,
    required this.timestamp,
    required this.message,
  });

  final ConsoleEntrySource source;
  final DateTime timestamp;
  final String message;
}
