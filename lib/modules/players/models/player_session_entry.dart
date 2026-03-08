class PlayerSessionEntry {
  const PlayerSessionEntry({
    required this.id,
    required this.playerId,
    required this.nickname,
    required this.startAt,
    required this.endAt,
    required this.lastSeenAt,
    required this.isOpen,
    required this.isIncomplete,
    required this.closeReason,
  });

  final int id;
  final int playerId;
  final String nickname;
  final DateTime startAt;
  final DateTime? endAt;
  final DateTime? lastSeenAt;
  final bool isOpen;
  final bool isIncomplete;
  final String? closeReason;

  Duration get duration {
    final end = endAt ?? lastSeenAt ?? DateTime.now();
    final delta = end.difference(startAt);
    if (delta.isNegative) {
      return Duration.zero;
    }
    return delta;
  }
}
