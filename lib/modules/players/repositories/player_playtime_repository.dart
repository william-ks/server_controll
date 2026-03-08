import 'package:intl/intl.dart';

import '../../../database/app_database.dart';
import '../models/player_playtime_summary.dart';
import '../models/player_session_entry.dart';

class PlayerPlaytimeRepository {
  PlayerPlaytimeRepository({AppDatabase? db})
    : _appDatabase = db ?? AppDatabase.instance;

  final AppDatabase _appDatabase;

  Future<void> ensureTickSetting({int defaultSeconds = 5}) async {
    final current = await _appDatabase.getSetting('playtime_tick_seconds');
    if (current != null && int.tryParse(current) != null) {
      return;
    }
    await _appDatabase.setSetting('playtime_tick_seconds', '$defaultSeconds');
  }

  Future<int> getTickSeconds({int fallback = 5}) async {
    final raw = await _appDatabase.getSetting('playtime_tick_seconds');
    final parsed = int.tryParse(raw ?? '');
    if (parsed == null || parsed < 1) {
      return fallback;
    }
    return parsed;
  }

  Future<void> markOpenSessionsAsUnexpectedShutdown() async {
    await closeAllOpenSessions(
      reason: 'app_shutdown_unexpected',
      incomplete: true,
    );
  }

  Future<bool> openSessionForNickname(
    String nickname, {
    String? uuid,
    DateTime? at,
  }) async {
    final normalizedNickname = nickname.trim();
    if (normalizedNickname.isEmpty) return false;

    final now = at ?? DateTime.now();
    final db = await _appDatabase.database;
    final playerId = await _ensurePlayerId(
      db,
      normalizedNickname,
      uuid: uuid,
      now: now,
    );
    final openSessionId = await _findOpenSessionId(db, playerId);
    if (openSessionId != null) {
      await db.update(
        'player_sessions',
        {
          'last_seen_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [openSessionId],
      );
      return false;
    }

    await db.insert('player_sessions', {
      'player_id': playerId,
      'is_open': 1,
      'is_incomplete': 0,
      'start_at': now.toIso8601String(),
      'end_at': null,
      'last_seen_at': now.toIso8601String(),
      'close_reason': null,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });
    return true;
  }

  Future<bool> closeSessionForNickname(
    String nickname, {
    required String reason,
    bool incomplete = false,
    DateTime? at,
  }) async {
    final normalizedNickname = nickname.trim();
    if (normalizedNickname.isEmpty) return false;

    final db = await _appDatabase.database;
    final playerId = await _findPlayerIdByNickname(db, normalizedNickname);
    if (playerId == null) return false;
    return _closeSessionByPlayerId(
      db,
      playerId,
      reason: reason,
      incomplete: incomplete,
      at: at ?? DateTime.now(),
    );
  }

  Future<bool> closeAllOpenSessions({
    required String reason,
    bool incomplete = false,
  }) async {
    final db = await _appDatabase.database;
    final now = DateTime.now();
    final openRows = await db.query(
      'player_sessions',
      columns: ['id', 'player_id'],
      where: 'is_open = 1',
    );
    if (openRows.isEmpty) return false;

    final playerIds = <int>{};
    for (final row in openRows) {
      final playerId = row['player_id'] as int? ?? 0;
      if (playerId > 0) {
        playerIds.add(playerId);
      }
    }

    await db.update('player_sessions', {
      'is_open': 0,
      'is_incomplete': incomplete ? 1 : 0,
      'end_at': now.toIso8601String(),
      'last_seen_at': now.toIso8601String(),
      'close_reason': reason,
      'updated_at': now.toIso8601String(),
    }, where: 'is_open = 1');

    for (final playerId in playerIds) {
      await _rebuildAggregatesForPlayer(db, playerId);
    }
    return true;
  }

  Future<bool> reconcilePresence(
    List<String> onlinePlayers, {
    required String closeReason,
  }) async {
    final now = DateTime.now();
    final db = await _appDatabase.database;
    final normalizedOnline = <String, String>{};
    for (final nickname in onlinePlayers) {
      final original = nickname.trim();
      final normalized = original.toLowerCase();
      if (normalized.isNotEmpty) {
        normalizedOnline[normalized] = original;
      }
    }

    var changed = false;
    for (final entry in normalizedOnline.entries) {
      final nickname = entry.value;
      final opened = await openSessionForNickname(nickname, at: now);
      if (opened) {
        changed = true;
      }
    }

    final openRows = await db.rawQuery('''
      SELECT
        s.id AS session_id,
        s.player_id AS player_id,
        p.nickname AS nickname
      FROM player_sessions s
      INNER JOIN players p ON p.id = s.player_id
      WHERE s.is_open = 1
    ''');

    for (final row in openRows) {
      final nickname = ((row['nickname'] as String?) ?? '')
          .trim()
          .toLowerCase();
      if (nickname.isEmpty) continue;
      if (normalizedOnline.containsKey(nickname)) {
        await db.update(
          'player_sessions',
          {
            'last_seen_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [row['session_id']],
        );
      } else {
        final playerId = row['player_id'] as int? ?? 0;
        if (playerId <= 0) continue;
        final closed = await _closeSessionByPlayerId(
          db,
          playerId,
          reason: closeReason,
          incomplete: true,
          at: now,
        );
        if (closed) {
          changed = true;
        }
      }
    }
    return changed;
  }

  Future<List<PlayerPlaytimeSummary>> fetchRanking() async {
    final db = await _appDatabase.database;
    final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final weekKey = _toWeekKey(DateTime.now());

    final rows = await db.rawQuery(
      '''
      SELECT
        p.id AS player_id,
        p.nickname AS nickname,
        COALESCE(d.total_seconds, 0) AS daily_seconds,
        COALESCE(w.total_seconds, 0) AS weekly_seconds,
        COALESCE(t.total_seconds, 0) AS total_seconds
      FROM players p
      LEFT JOIN player_playtime_aggregates d
        ON d.player_id = p.id
       AND d.period_type = 'daily'
       AND d.period_key = ?
      LEFT JOIN player_playtime_aggregates w
        ON w.player_id = p.id
       AND w.period_type = 'weekly'
       AND w.period_key = ?
      LEFT JOIN player_playtime_aggregates t
        ON t.player_id = p.id
       AND t.period_type = 'total'
       AND t.period_key = 'all'
      ORDER BY total_seconds DESC, LOWER(p.nickname) ASC
    ''',
      [todayKey, weekKey],
    );

    return rows.map((row) {
      return PlayerPlaytimeSummary(
        playerId: row['player_id'] as int? ?? 0,
        nickname: row['nickname'] as String? ?? '',
        dailySeconds: row['daily_seconds'] as int? ?? 0,
        weeklySeconds: row['weekly_seconds'] as int? ?? 0,
        totalSeconds: row['total_seconds'] as int? ?? 0,
      );
    }).toList();
  }

  Future<List<PlayerSessionEntry>> fetchPlayerHistory(
    int playerId, {
    int limit = 30,
  }) async {
    final db = await _appDatabase.database;
    final rows = await db.rawQuery(
      '''
      SELECT
        s.id AS id,
        s.player_id AS player_id,
        p.nickname AS nickname,
        s.start_at AS start_at,
        s.end_at AS end_at,
        s.last_seen_at AS last_seen_at,
        s.is_open AS is_open,
        s.is_incomplete AS is_incomplete,
        s.close_reason AS close_reason
      FROM player_sessions s
      INNER JOIN players p ON p.id = s.player_id
      WHERE s.player_id = ?
      ORDER BY s.start_at DESC
      LIMIT ?
    ''',
      [playerId, limit],
    );

    return rows.map((row) {
      return PlayerSessionEntry(
        id: row['id'] as int? ?? 0,
        playerId: row['player_id'] as int? ?? 0,
        nickname: row['nickname'] as String? ?? '',
        startAt:
            DateTime.tryParse((row['start_at'] as String?) ?? '') ??
            DateTime.now(),
        endAt: DateTime.tryParse((row['end_at'] as String?) ?? ''),
        lastSeenAt: DateTime.tryParse((row['last_seen_at'] as String?) ?? ''),
        isOpen: (row['is_open'] as int? ?? 0) == 1,
        isIncomplete: (row['is_incomplete'] as int? ?? 0) == 1,
        closeReason: row['close_reason'] as String?,
      );
    }).toList();
  }

  Future<int?> findPlayerIdByNickname(String nickname) async {
    final db = await _appDatabase.database;
    return _findPlayerIdByNickname(db, nickname);
  }

  Future<int?> _findPlayerIdByNickname(dynamic db, String nickname) async {
    final trimmed = nickname.trim();
    if (trimmed.isEmpty) return null;
    final rows = await db.query(
      'players',
      columns: ['id'],
      where: 'LOWER(nickname) = ?',
      whereArgs: [trimmed.toLowerCase()],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['id'] as int?;
  }

  Future<int> _ensurePlayerId(
    dynamic db,
    String nickname, {
    String? uuid,
    required DateTime now,
  }) async {
    final normalizedNickname = nickname.trim();
    final normalizedUuid = uuid?.trim();
    final existingId = await _findPlayerIdByNickname(db, normalizedNickname);
    if (existingId != null) {
      if (normalizedUuid != null && normalizedUuid.isNotEmpty) {
        await db.update(
          'players',
          {'uuid': normalizedUuid, 'updated_at': now.toIso8601String()},
          where: 'id = ?',
          whereArgs: [existingId],
        );
      } else {
        await db.update(
          'players',
          {'updated_at': now.toIso8601String()},
          where: 'id = ?',
          whereArgs: [existingId],
        );
      }
      return existingId;
    }

    return db.insert('players', {
      'nickname': normalizedNickname,
      'uuid': normalizedUuid == null || normalizedUuid.isEmpty
          ? null
          : normalizedUuid,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });
  }

  Future<int?> _findOpenSessionId(dynamic db, int playerId) async {
    final rows = await db.query(
      'player_sessions',
      columns: ['id'],
      where: 'player_id = ? AND is_open = 1',
      whereArgs: [playerId],
      orderBy: 'start_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['id'] as int?;
  }

  Future<bool> _closeSessionByPlayerId(
    dynamic db,
    int playerId, {
    required String reason,
    required bool incomplete,
    required DateTime at,
  }) async {
    final openSessionId = await _findOpenSessionId(db, playerId);
    if (openSessionId == null) return false;
    await db.update(
      'player_sessions',
      {
        'is_open': 0,
        'is_incomplete': incomplete ? 1 : 0,
        'end_at': at.toIso8601String(),
        'last_seen_at': at.toIso8601String(),
        'close_reason': reason,
        'updated_at': at.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [openSessionId],
    );
    await _rebuildAggregatesForPlayer(db, playerId);
    return true;
  }

  Future<void> _rebuildAggregatesForPlayer(dynamic db, int playerId) async {
    final rows = await db.query(
      'player_sessions',
      columns: ['start_at', 'end_at', 'last_seen_at', 'is_open'],
      where: 'player_id = ?',
      whereArgs: [playerId],
    );

    final byDay = <String, int>{};
    final byWeek = <String, int>{};
    var totalSeconds = 0;
    for (final row in rows) {
      final start = DateTime.tryParse((row['start_at'] as String?) ?? '');
      if (start == null) {
        continue;
      }
      DateTime? end;
      if ((row['is_open'] as int? ?? 0) == 1) {
        end = DateTime.tryParse((row['last_seen_at'] as String?) ?? '');
      } else {
        end =
            DateTime.tryParse((row['end_at'] as String?) ?? '') ??
            DateTime.tryParse((row['last_seen_at'] as String?) ?? '');
      }
      if (end == null) {
        continue;
      }
      final durationSeconds = end.difference(start).inSeconds;
      if (durationSeconds <= 0) {
        continue;
      }

      totalSeconds += durationSeconds;
      final dayKey = DateFormat('yyyy-MM-dd').format(start.toLocal());
      byDay[dayKey] = (byDay[dayKey] ?? 0) + durationSeconds;

      final weekKey = _toWeekKey(start.toLocal());
      byWeek[weekKey] = (byWeek[weekKey] ?? 0) + durationSeconds;
    }

    final nowIso = DateTime.now().toIso8601String();
    await db.delete(
      'player_playtime_aggregates',
      where: 'player_id = ?',
      whereArgs: [playerId],
    );

    if (totalSeconds > 0) {
      await db.insert('player_playtime_aggregates', {
        'player_id': playerId,
        'period_type': 'total',
        'period_key': 'all',
        'total_seconds': totalSeconds,
        'updated_at': nowIso,
      });
    }

    for (final entry in byDay.entries) {
      await db.insert('player_playtime_aggregates', {
        'player_id': playerId,
        'period_type': 'daily',
        'period_key': entry.key,
        'total_seconds': entry.value,
        'updated_at': nowIso,
      });
    }

    for (final entry in byWeek.entries) {
      await db.insert('player_playtime_aggregates', {
        'player_id': playerId,
        'period_type': 'weekly',
        'period_key': entry.key,
        'total_seconds': entry.value,
        'updated_at': nowIso,
      });
    }
  }

  String _toWeekKey(DateTime date) {
    final thursday = date.add(Duration(days: 4 - date.weekday));
    final yearStart = DateTime(thursday.year, 1, 1);
    final week = ((thursday.difference(yearStart).inDays) / 7).floor() + 1;
    return '${thursday.year}-W${week.toString().padLeft(2, '0')}';
  }
}
