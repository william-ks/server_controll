import '../../../database/app_database.dart';
import '../models/whitelist_player.dart';

class WhitelistRepository {
  Future<List<WhitelistPlayer>> getAll() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('whitelist_players', orderBy: 'nickname COLLATE NOCASE ASC');
    return rows.map(WhitelistPlayer.fromMap).toList();
  }

  Future<int> insert(WhitelistPlayer player) async {
    final db = await AppDatabase.instance.database;
    final map = player.toMap()..remove('id');
    return db.insert('whitelist_players', map);
  }

  Future<void> upsertByNickname(WhitelistPlayer player) async {
    final db = await AppDatabase.instance.database;
    final existing = await db.query(
      'whitelist_players',
      where: 'nickname = ?',
      whereArgs: [player.nickname],
      limit: 1,
    );

    if (existing.isEmpty) {
      await insert(player);
      return;
    }

    await db.update(
      'whitelist_players',
      player.toMap()..remove('id')..remove('created_at'),
      where: 'nickname = ?',
      whereArgs: [player.nickname],
    );
  }

  Future<void> update(WhitelistPlayer player) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'whitelist_players',
      player.toMap()..remove('created_at'),
      where: 'id = ?',
      whereArgs: [player.id],
    );
  }

  Future<void> delete(int id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('whitelist_players', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteByNickname(String nickname) async {
    final db = await AppDatabase.instance.database;
    await db.delete(
      'whitelist_players',
      where: 'LOWER(nickname) = ?',
      whereArgs: [nickname.trim().toLowerCase()],
    );
  }

  Future<List<WhitelistPlayer>> pending() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'whitelist_players',
      where: "is_pending = 1 AND COALESCE(pending_action, 'add') = 'add'",
    );
    return rows.map(WhitelistPlayer.fromMap).toList();
  }

  Future<List<WhitelistPlayer>> pendingRemovals() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'whitelist_players',
      where: "is_pending = 1 AND pending_action = 'remove'",
    );
    return rows.map(WhitelistPlayer.fromMap).toList();
  }

  Future<void> markPendingRemoval(int id) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'whitelist_players',
      {
        'is_pending': 1,
        'pending_action': 'remove',
        'is_added': 1,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> cancelPendingRemoval(int id) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'whitelist_players',
      {
        'is_pending': 0,
        'pending_action': null,
        'is_added': 1,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: "id = ? AND is_pending = 1 AND pending_action = 'remove'",
      whereArgs: [id],
    );
  }
}

