enum PlayerRankingPeriod { daily, weekly, monthly }

extension PlayerRankingPeriodX on PlayerRankingPeriod {
  String get label => switch (this) {
    PlayerRankingPeriod.daily => 'Diário',
    PlayerRankingPeriod.weekly => 'Semanal',
    PlayerRankingPeriod.monthly => 'Mensal',
  };
}
