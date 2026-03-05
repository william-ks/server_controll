class ServerLogParser {
  static final RegExp _overloadRegex = RegExp(
    r"Can't keep up! Is the server overloaded\? Running (\d+)ms or (\d+) ticks behind",
  );

  static bool isServerReady(String line) {
    return line.contains('Done (') && line.contains('For help, type');
  }

  static ServerOverloadEvent? parseOverload(String line) {
    final match = _overloadRegex.firstMatch(line);
    if (match == null) return null;
    final msBehind = int.tryParse(match.group(1) ?? '');
    final ticksBehind = int.tryParse(match.group(2) ?? '');
    if (msBehind == null || ticksBehind == null) return null;
    return ServerOverloadEvent(msBehind: msBehind, ticksBehind: ticksBehind);
  }

  static int? parsePlayersOnline(String line) {
    final regex = RegExp(
      r'There are\s+(\d+)\s+of a max of\s+\d+\s+players online',
    );
    final match = regex.firstMatch(line);
    if (match == null) {
      return null;
    }
    return int.tryParse(match.group(1)!);
  }

  static List<String>? parseOnlinePlayersList(String line) {
    final regex = RegExp(
      r'There are\s+\d+\s+of a max of\s+\d+\s+players online:\s*(.*)$',
    );
    final match = regex.firstMatch(line);
    if (match == null) {
      return null;
    }

    final namesRaw = match.group(1)?.trim() ?? '';
    if (namesRaw.isEmpty) {
      return <String>[];
    }

    return namesRaw
        .split(',')
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList();
  }

  static String? parseJoinedPlayer(String line) {
    final match = RegExp(r'\]:\s(.+) joined the game').firstMatch(line);
    return match?.group(1)?.trim();
  }

  static String? parseLeftPlayer(String line) {
    final match = RegExp(r'\]:\s(.+) left the game').firstMatch(line);
    return match?.group(1)?.trim();
  }

  static bool isStopping(String line) {
    return line.toLowerCase().contains('stopping server');
  }
}

class ServerOverloadEvent {
  const ServerOverloadEvent({
    required this.msBehind,
    required this.ticksBehind,
  });

  final int msBehind;
  final int ticksBehind;
}
