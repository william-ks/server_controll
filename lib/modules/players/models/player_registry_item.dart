class PlayerRegistryItem {
  const PlayerRegistryItem({
    required this.id,
    required this.nickname,
    required this.uuid,
    required this.isWhitelisted,
    required this.isAppAdmin,
    required this.isOp,
    required this.isBanned,
    required this.hasIdentityConflict,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String nickname;
  final String? uuid;
  final bool isWhitelisted;
  final bool isAppAdmin;
  final bool isOp;
  final bool isBanned;
  final bool hasIdentityConflict;
  final DateTime createdAt;
  final DateTime updatedAt;
}
