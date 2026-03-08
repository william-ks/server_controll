class PlayerPlaytimeSummary {
  const PlayerPlaytimeSummary({
    required this.playerId,
    required this.nickname,
    required this.dailySeconds,
    required this.weeklySeconds,
    required this.monthlySeconds,
    required this.totalSeconds,
  });

  final int playerId;
  final String nickname;
  final int dailySeconds;
  final int weeklySeconds;
  final int monthlySeconds;
  final int totalSeconds;
}
