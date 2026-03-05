import 'migration.dart';

class MigrationV5 implements Migration {
  @override
  int get version => 5;

  @override
  Future<void> up(dynamic db) async {
    await db.execute('''
      CREATE TABLE chunky_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        level TEXT NOT NULL,
        message TEXT NOT NULL,
        run_index INTEGER NOT NULL DEFAULT 0,
        total_runs INTEGER NOT NULL DEFAULT 0,
        radius INTEGER NOT NULL DEFAULT 0,
        elapsed_seconds INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.insert('schema_migrations', {
      'version': version,
      'executed_at': DateTime.now().toIso8601String(),
    });
  }
}
