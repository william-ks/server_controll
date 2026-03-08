import '../../../database/app_database.dart';
import '../models/player_permission_status.dart';

class PendingPermissionAction {
  const PendingPermissionAction({
    required this.id,
    required this.nickname,
    required this.actionType,
  });

  final int id;
  final String nickname;
  final String actionType;
}

class PlayerPermissionsRepository {
  PlayerPermissionsRepository({AppDatabase? db})
    : _db = db ?? AppDatabase.instance;

  final AppDatabase _db;

  Future<int> ensurePlayer(String nickname, {String? uuid}) async {
    final trimmed = nickname.trim();
    if (trimmed.isEmpty) {
      throw StateError('Nickname inválido para permissão.');
    }
    final db = await _db.database;
    final existing = await db.query(
      'players',
      columns: ['id'],
      where: 'LOWER(nickname) = ?',
      whereArgs: [trimmed.toLowerCase()],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      final id = existing.first['id'] as int;
      await db.update(
        'players',
        {
          'updated_at': DateTime.now().toIso8601String(),
          if (uuid != null && uuid.trim().isNotEmpty) 'uuid': uuid.trim(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      return id;
    }

    return db.insert('players', {
      'nickname': trimmed,
      'uuid': uuid?.trim().isNotEmpty == true ? uuid!.trim() : null,
      'is_player': 1,
      'is_whitelisted': 0,
      'is_app_admin': 0,
      'is_op': 0,
      'is_banned': 0,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> syncWhitelistFlags(List<String> whitelistedNicknames) async {
    final db = await _db.database;
    final target = <String>{
      for (final nickname in whitelistedNicknames)
        if (nickname.trim().isNotEmpty) nickname.trim().toLowerCase(),
    };

    final allRows = await db.query('players', columns: ['id', 'nickname']);
    for (final row in allRows) {
      final id = row['id'] as int? ?? 0;
      final nickname = (row['nickname'] as String? ?? '').trim().toLowerCase();
      if (id <= 0 || nickname.isEmpty) continue;
      await db.update(
        'players',
        {
          'is_whitelisted': target.contains(nickname) ? 1 : 0,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }

    for (final nickname in target) {
      await ensurePlayer(nickname);
      await db.update(
        'players',
        {'is_whitelisted': 1, 'updated_at': DateTime.now().toIso8601String()},
        where: 'LOWER(nickname) = ?',
        whereArgs: [nickname],
      );
    }
  }

  Future<void> setAppAdmin(String nickname, bool enabled) async {
    final playerId = await ensurePlayer(nickname);
    final db = await _db.database;
    await db.update(
      'players',
      {
        'is_app_admin': enabled ? 1 : 0,
        if (!enabled) 'is_op': 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [playerId],
    );
  }

  Future<void> setOpStatus(String nickname, bool enabled) async {
    final playerId = await ensurePlayer(nickname);
    final db = await _db.database;
    if (enabled) {
      final rows = await db.query(
        'players',
        columns: ['is_app_admin'],
        where: 'id = ?',
        whereArgs: [playerId],
        limit: 1,
      );
      final isAppAdmin = (rows.first['is_app_admin'] as int? ?? 0) == 1;
      if (!isAppAdmin) {
        throw StateError(
          'Todo OP precisa ser admin do app. Promova para admin primeiro.',
        );
      }
    }

    await db.update(
      'players',
      {
        'is_op': enabled ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [playerId],
    );
  }

  Future<void> enqueuePendingOpAction({
    required String nickname,
    required bool promote,
  }) async {
    final playerId = await ensurePlayer(nickname);
    final db = await _db.database;
    await db.insert('permission_pending_actions', {
      'player_id': playerId,
      'nickname': nickname.trim(),
      'action_type': promote ? 'op' : 'deop',
      'status': 'pending',
      'error_message': null,
      'created_at': DateTime.now().toIso8601String(),
      'applied_at': null,
    });
  }

  Future<List<PendingPermissionAction>> loadPendingActions() async {
    final db = await _db.database;
    final rows = await db.query(
      'permission_pending_actions',
      columns: ['id', 'nickname', 'action_type'],
      where: "status = 'pending'",
      orderBy: 'created_at ASC',
    );
    return rows.map((row) {
      return PendingPermissionAction(
        id: row['id'] as int? ?? 0,
        nickname: row['nickname'] as String? ?? '',
        actionType: row['action_type'] as String? ?? '',
      );
    }).toList();
  }

  Future<void> markPendingApplied(int id) async {
    final db = await _db.database;
    await db.update(
      'permission_pending_actions',
      {
        'status': 'applied',
        'error_message': null,
        'applied_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markPendingFailed(int id, String error) async {
    final db = await _db.database;
    await db.update(
      'permission_pending_actions',
      {'status': 'error', 'error_message': error},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<PlayerPermissionStatus> getStatusForNickname(String nickname) async {
    final statuses = await listStatusesByNicknames([nickname]);
    return statuses[nickname.trim().toLowerCase()] ??
        PlayerPermissionStatus(
          nickname: nickname.trim(),
          isPlayer: true,
          isWhitelisted: false,
          isAppAdmin: false,
          isOp: false,
          isBanned: false,
          pendingOpsCount: 0,
        );
  }

  Future<Map<String, PlayerPermissionStatus>> listStatusesByNicknames(
    List<String> nicknames,
  ) async {
    final normalized = <String>{
      for (final nickname in nicknames)
        if (nickname.trim().isNotEmpty) nickname.trim().toLowerCase(),
    }.toList();
    final result = <String, PlayerPermissionStatus>{};
    if (normalized.isEmpty) {
      return result;
    }

    final db = await _db.database;
    final placeholders = List.filled(normalized.length, '?').join(',');

    final rows = await db.rawQuery('''
      SELECT
        p.nickname AS nickname,
        p.is_player AS is_player,
        p.is_whitelisted AS is_whitelisted,
        p.is_app_admin AS is_app_admin,
        p.is_op AS is_op,
        p.is_banned AS is_banned,
        COALESCE(pa.pending_count, 0) AS pending_count
      FROM players p
      LEFT JOIN (
        SELECT
          LOWER(nickname) AS nickname_key,
          COUNT(*) AS pending_count
        FROM permission_pending_actions
        WHERE status = 'pending'
        GROUP BY LOWER(nickname)
      ) pa ON pa.nickname_key = LOWER(p.nickname)
      WHERE LOWER(p.nickname) IN ($placeholders)
    ''', normalized);

    for (final row in rows) {
      final nickname = (row['nickname'] as String? ?? '').trim();
      if (nickname.isEmpty) continue;
      final key = nickname.toLowerCase();
      result[key] = PlayerPermissionStatus(
        nickname: nickname,
        isPlayer: (row['is_player'] as int? ?? 1) == 1,
        isWhitelisted: (row['is_whitelisted'] as int? ?? 0) == 1,
        isAppAdmin: (row['is_app_admin'] as int? ?? 0) == 1,
        isOp: (row['is_op'] as int? ?? 0) == 1,
        isBanned: (row['is_banned'] as int? ?? 0) == 1,
        pendingOpsCount: row['pending_count'] as int? ?? 0,
      );
    }

    return result;
  }
}
