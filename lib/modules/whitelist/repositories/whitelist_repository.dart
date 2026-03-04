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

  Future<List<WhitelistPlayer>> pending() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('whitelist_players', where: 'is_pending = 1');
    return rows.map(WhitelistPlayer.fromMap).toList();
  }
}
