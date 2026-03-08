import '../../../database/app_database.dart';
import 'player_permissions_repository.dart';

class PlayerBanRepository {
  PlayerBanRepository({
    AppDatabase? db,
    PlayerPermissionsRepository? permissionsRepository,
  }) : _db = db ?? AppDatabase.instance,
       _permissionsRepository =
           permissionsRepository ?? PlayerPermissionsRepository();

  final AppDatabase _db;
  final PlayerPermissionsRepository _permissionsRepository;

  Future<void> banPlayer({
    required String nickname,
    required String reason,
    required bool pendingBan,
    Duration? duration,
    String createdBy = 'app_operator',
  }) async {
    final playerId = await _permissionsRepository.ensurePlayer(nickname);
    final db = await _db.database;
    final now = DateTime.now();
    final expiresAt = duration == null ? null : now.add(duration);

    await db.insert('player_bans', {
      'player_id': playerId,
      'reason': reason.trim().isEmpty ? null : reason.trim(),
      'starts_at': now.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'is_active': 1,
      'pending_ban': pendingBan ? 1 : 0,
      'pending_unban': 0,
      'created_by': createdBy,
      'removed_by': null,
      'removed_at': null,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });

    await db.update(
      'players',
      {'is_banned': 1, 'updated_at': now.toIso8601String()},
      where: 'id = ?',
      whereArgs: [playerId],
    );

    await _appendStatusHistory(
      db,
      playerId: playerId,
      statusType: 'ban',
      oldValue: '0',
      newValue: '1',
      note: reason.trim(),
      changedBy: createdBy,
    );

    if (!pendingBan) {
      await _applyBanConsequences(
        db,
        playerId: playerId,
        nickname: nickname,
      );
    }
  }

  Future<void> unbanPlayer({
    required String nickname,
    required String removedBy,
    required bool pendingUnban,
  }) async {
    final db = await _db.database;
    final player = await db.query(
      'players',
      columns: ['id'],
      where: 'LOWER(nickname) = ?',
      whereArgs: [nickname.trim().toLowerCase()],
      limit: 1,
    );
    if (player.isEmpty) return;
    final playerId = player.first['id'] as int;
    final now = DateTime.now();

    await db.update(
      'player_bans',
      {
        'is_active': 0,
        'pending_ban': 0,
        'pending_unban': pendingUnban ? 1 : 0,
        'removed_by': removedBy,
        'removed_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      },
      where: 'player_id = ? AND is_active = 1',
      whereArgs: [playerId],
    );

    final hasOtherActive = await _hasActiveBan(db, playerId);
    if (!hasOtherActive) {
      await db.update(
        'players',
        {'is_banned': 0, 'updated_at': now.toIso8601String()},
        where: 'id = ?',
        whereArgs: [playerId],
      );
      await _appendStatusHistory(
        db,
        playerId: playerId,
        statusType: 'ban',
        oldValue: '1',
        newValue: '0',
        changedBy: removedBy,
      );
    }
  }

  Future<void> cancelPendingBan({
    required String nickname,
    String removedBy = 'app_operator',
  }) async {
    final db = await _db.database;
    final player = await db.query(
      'players',
      columns: ['id'],
      where: 'LOWER(nickname) = ?',
      whereArgs: [nickname.trim().toLowerCase()],
      limit: 1,
    );
    if (player.isEmpty) return;
    final playerId = player.first['id'] as int;
    final now = DateTime.now();

    await db.update(
      'player_bans',
      {
        'is_active': 0,
        'pending_ban': 0,
        'pending_unban': 0,
        'removed_by': removedBy,
        'removed_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      },
      where: 'player_id = ? AND is_active = 1 AND pending_ban = 1',
      whereArgs: [playerId],
    );

    final hasOtherActive = await _hasActiveBan(db, playerId);
    if (!hasOtherActive) {
      await db.update(
        'players',
        {'is_banned': 0, 'updated_at': now.toIso8601String()},
        where: 'id = ?',
        whereArgs: [playerId],
      );
      await _appendStatusHistory(
        db,
        playerId: playerId,
        statusType: 'ban',
        oldValue: '1',
        newValue: '0',
        changedBy: removedBy,
        note: 'banimento pendente cancelado',
      );
    }
  }

  Future<void> processExpiredBans({
    required bool isServerOnline,
    required Future<void> Function(String nickname) onPardon,
  }) async {
    final db = await _db.database;
    final now = DateTime.now();
    final rows = await db.rawQuery(
      '''
      SELECT
        b.id AS ban_id,
        b.player_id AS player_id,
        p.nickname AS nickname
      FROM player_bans b
      INNER JOIN players p ON p.id = b.player_id
      WHERE b.is_active = 1
        AND b.expires_at IS NOT NULL
        AND b.expires_at <= ?
    ''',
      [now.toIso8601String()],
    );
    if (rows.isEmpty) return;

    for (final row in rows) {
      final banId = row['ban_id'] as int? ?? 0;
      final playerId = row['player_id'] as int? ?? 0;
      final nickname = row['nickname'] as String? ?? '';
      if (banId <= 0 || playerId <= 0 || nickname.trim().isEmpty) continue;

      await db.update(
        'player_bans',
        {
          'is_active': 0,
          'pending_ban': 0,
          'pending_unban': isServerOnline ? 0 : 1,
          'removed_by': 'auto_expire',
          'removed_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [banId],
      );

      if (isServerOnline) {
        await onPardon(nickname);
      }

      final hasStillActive = await _hasActiveBan(db, playerId);
      if (!hasStillActive) {
        await db.update(
          'players',
          {'is_banned': 0, 'updated_at': now.toIso8601String()},
          where: 'id = ?',
          whereArgs: [playerId],
        );
        await _appendStatusHistory(
          db,
          playerId: playerId,
          statusType: 'ban',
          oldValue: '1',
          newValue: '0',
          changedBy: 'auto_expire',
          note: 'ban temporário expirado',
        );
      }
    }
  }

  Future<void> processPendingUnban({
    required bool isServerOnline,
    required Future<void> Function(String nickname) onPardon,
  }) async {
    if (!isServerOnline) return;
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT
        b.id AS ban_id,
        p.nickname AS nickname
      FROM player_bans b
      INNER JOIN players p ON p.id = b.player_id
      WHERE b.pending_unban = 1
      ORDER BY b.updated_at ASC
    ''');

    for (final row in rows) {
      final id = row['ban_id'] as int? ?? 0;
      final nickname = row['nickname'] as String? ?? '';
      if (id <= 0 || nickname.trim().isEmpty) continue;
      await onPardon(nickname);
      await db.update(
        'player_bans',
        {'pending_unban': 0, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  Future<void> processPendingBan({
    required bool isServerOnline,
    required Future<void> Function(String nickname, String? reason) onBan,
  }) async {
    if (!isServerOnline) return;
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT
        b.id AS ban_id,
        b.player_id AS player_id,
        p.nickname AS nickname,
        b.reason AS reason
      FROM player_bans b
      INNER JOIN players p ON p.id = b.player_id
      WHERE b.pending_ban = 1
        AND b.is_active = 1
      ORDER BY b.updated_at ASC
    ''');
    for (final row in rows) {
      final id = row['ban_id'] as int? ?? 0;
      final playerId = row['player_id'] as int? ?? 0;
      final nickname = row['nickname'] as String? ?? '';
      final reason = row['reason'] as String?;
      if (id <= 0 || playerId <= 0 || nickname.trim().isEmpty) continue;
      await onBan(nickname, reason);
      await db.update(
        'player_bans',
        {'pending_ban': 0, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
      await _applyBanConsequences(
        db,
        playerId: playerId,
        nickname: nickname,
      );
    }
  }

  Future<bool> _hasActiveBan(dynamic db, int playerId) async {
    final rows = await db.query(
      'player_bans',
      columns: ['id'],
      where: 'player_id = ? AND is_active = 1',
      whereArgs: [playerId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> _appendStatusHistory(
    dynamic db, {
    required int playerId,
    required String statusType,
    required String oldValue,
    required String newValue,
    required String changedBy,
    String? note,
  }) async {
    await db.insert('player_status_history', {
      'player_id': playerId,
      'status_type': statusType,
      'old_value': oldValue,
      'new_value': newValue,
      'changed_by': changedBy,
      'note': note,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _applyBanConsequences(
    dynamic db, {
    required int playerId,
    required String nickname,
  }) async {
    final trimmedNickname = nickname.trim().toLowerCase();
    await db.delete(
      'whitelist_players',
      where: 'LOWER(nickname) = ?',
      whereArgs: [trimmedNickname],
    );
    await db.update(
      'players',
      {
        'is_whitelisted': 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [playerId],
    );
    await db.delete('player_sessions', where: 'player_id = ?', whereArgs: [playerId]);
    await db.delete(
      'player_playtime_aggregates',
      where: 'player_id = ?',
      whereArgs: [playerId],
    );
  }
}
