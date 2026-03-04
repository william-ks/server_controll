class ServerLogParser {
  static bool isServerReady(String line) {
    return line.contains('Done (') && line.contains('For help, type');
  }

  static int? parsePlayersOnline(String line) {
    final regex = RegExp(r'There are\s+(\d+)\s+of a max of\s+\d+\s+players online');
    final match = regex.firstMatch(line);
    if (match == null) {
      return null;
    }
    return int.tryParse(match.group(1)!);
  }

  static bool isStopping(String line) {
    return line.toLowerCase().contains('stopping server');
  }
}
