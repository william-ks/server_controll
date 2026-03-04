import 'migration.dart';

class MigrationV2 implements Migration {
  @override
  int get version => 2;

  @override
  Future<void> up(dynamic db) async {
    await db.execute('''
      CREATE TABLE whitelist_players (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nickname TEXT NOT NULL,
        uuid TEXT,
        icon_path TEXT,
        is_pending INTEGER NOT NULL DEFAULT 1,
        is_added INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.insert('schema_migrations', {
      'version': version,
      'executed_at': DateTime.now().toIso8601String(),
    });
  }
}
