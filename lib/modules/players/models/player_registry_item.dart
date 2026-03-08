class PlayerRegistryItem {
  const PlayerRegistryItem({
    required this.id,
    required this.nickname,
    required this.uuid,
    required this.iconPath,
    required this.isWhitelisted,
    required this.isAppAdmin,
    required this.isOp,
    required this.isBanned,
    required this.isBanPending,
    required this.isUnbanPending,
    required this.hasIdentityConflict,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String nickname;
  final String? uuid;
  final String? iconPath;
  final bool isWhitelisted;
  final bool isAppAdmin;
  final bool isOp;
  final bool isBanned;
  final bool isBanPending;
  final bool isUnbanPending;
  final bool hasIdentityConflict;
  final DateTime createdAt;
  final DateTime updatedAt;
}
