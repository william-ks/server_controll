import '../../../database/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
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
      await _upsertPrimaryIdentity(
        db,
        playerId: id,
        nickname: trimmed,
        uuid: uuid,
      );
      return id;
    }

    final id = await db.insert('players', {
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
    await _upsertPrimaryIdentity(
      db,
      playerId: id,
      nickname: trimmed,
      uuid: uuid,
    );
    return id;
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
      final currentRows = await db.query(
        'players',
        columns: ['is_whitelisted'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      final oldValue = (currentRows.first['is_whitelisted'] as int? ?? 0) == 1;
      final newValue = target.contains(nickname);
      await db.update(
        'players',
        {
          'is_whitelisted': newValue ? 1 : 0,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      if (oldValue != newValue) {
        await _appendStatusHistory(
          db,
          playerId: id,
          statusType: 'whitelist',
          oldValue: oldValue ? '1' : '0',
          newValue: newValue ? '1' : '0',
          changedBy: 'system_sync',
        );
      }
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
    final rows = await db.query(
      'players',
      columns: ['is_app_admin', 'is_op'],
      where: 'id = ?',
      whereArgs: [playerId],
      limit: 1,
    );
    final oldAdmin = (rows.first['is_app_admin'] as int? ?? 0) == 1;
    final oldOp = (rows.first['is_op'] as int? ?? 0) == 1;
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
    if (oldAdmin != enabled) {
      await _appendStatusHistory(
        db,
        playerId: playerId,
        statusType: 'app_admin',
        oldValue: oldAdmin ? '1' : '0',
        newValue: enabled ? '1' : '0',
      );
    }
    if (oldOp && !enabled) {
      await _appendStatusHistory(
        db,
        playerId: playerId,
        statusType: 'op',
        oldValue: '1',
        newValue: '0',
      );
    }
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

    final previousRows = await db.query(
      'players',
      columns: ['is_op'],
      where: 'id = ?',
      whereArgs: [playerId],
      limit: 1,
    );
    final oldValue = (previousRows.first['is_op'] as int? ?? 0) == 1;

    await db.update(
      'players',
      {
        'is_op': enabled ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [playerId],
    );
    if (oldValue != enabled) {
      await _appendStatusHistory(
        db,
        playerId: playerId,
        statusType: 'op',
        oldValue: oldValue ? '1' : '0',
        newValue: enabled ? '1' : '0',
      );
    }
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

  Future<void> _appendStatusHistory(
    dynamic db, {
    required int playerId,
    required String statusType,
    required String oldValue,
    required String newValue,
    String changedBy = 'app_operator',
  }) async {
    await db.insert('player_status_history', {
      'player_id': playerId,
      'status_type': statusType,
      'old_value': oldValue,
      'new_value': newValue,
      'changed_by': changedBy,
      'note': null,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _upsertPrimaryIdentity(
    dynamic db, {
    required int playerId,
    required String nickname,
    String? uuid,
  }) async {
    final now = DateTime.now().toIso8601String();
    final existing = await db.query(
      'player_identities',
      columns: ['id'],
      where: 'player_id = ? AND is_primary = 1',
      whereArgs: [playerId],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      await db.update(
        'player_identities',
        {
          'nickname': nickname,
          'uuid': uuid?.trim().isNotEmpty == true ? uuid!.trim() : null,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
      return;
    }

    await db.insert('player_identities', {
      'player_id': playerId,
      'nickname': nickname,
      'uuid': uuid?.trim().isNotEmpty == true ? uuid!.trim() : null,
      'is_primary': 1,
      'conflict_pending_manual_review': 0,
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }
}
