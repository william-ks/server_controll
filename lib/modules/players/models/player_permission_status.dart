class PlayerPermissionStatus {
  const PlayerPermissionStatus({
    required this.nickname,
    required this.isPlayer,
    required this.isWhitelisted,
    required this.isAppAdmin,
    required this.isOp,
    required this.isBanned,
    required this.pendingOpsCount,
  });

  final String nickname;
  final bool isPlayer;
  final bool isWhitelisted;
  final bool isAppAdmin;
  final bool isOp;
  final bool isBanned;
  final int pendingOpsCount;
}
