class PlayerRegistryHistoryEvent {
  const PlayerRegistryHistoryEvent({
    required this.playerNickname,
    required this.eventType,
    required this.description,
    required this.createdAt,
  });

  final String playerNickname;
  final String eventType;
  final String description;
  final DateTime createdAt;
}
