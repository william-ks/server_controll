class WhitelistPlayer {
  const WhitelistPlayer({
    this.id,
    required this.nickname,
    this.uuid,
    this.iconPath,
    required this.isPending,
    required this.isAdded,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final String nickname;
  final String? uuid;
  final String? iconPath;
  final bool isPending;
  final bool isAdded;
  final DateTime createdAt;
  final DateTime updatedAt;

  WhitelistPlayer copyWith({
    int? id,
    String? nickname,
    String? uuid,
    String? iconPath,
    bool? isPending,
    bool? isAdded,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WhitelistPlayer(
      id: id ?? this.id,
      nickname: nickname ?? this.nickname,
      uuid: uuid ?? this.uuid,
      iconPath: iconPath ?? this.iconPath,
      isPending: isPending ?? this.isPending,
      isAdded: isAdded ?? this.isAdded,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nickname': nickname,
      'uuid': uuid,
      'icon_path': iconPath,
      'is_pending': isPending ? 1 : 0,
      'is_added': isAdded ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory WhitelistPlayer.fromMap(Map<String, dynamic> map) {
    return WhitelistPlayer(
      id: map['id'] as int?,
      nickname: map['nickname'] as String,
      uuid: map['uuid'] as String?,
      iconPath: map['icon_path'] as String?,
      isPending: (map['is_pending'] as int) == 1,
      isAdded: (map['is_added'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}

