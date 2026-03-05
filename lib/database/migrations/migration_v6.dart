import 'migration.dart';

class MigrationV6 implements Migration {
  @override
  int get version => 6;

  @override
  Future<void> up(dynamic db) async {
    await db.execute('''
      CREATE TABLE chunky_tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        world TEXT NOT NULL,
        radius REAL NOT NULL,
        shape TEXT NOT NULL,
        pattern TEXT NOT NULL,
        backup_before_start INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'draft',
        has_ever_started INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        last_run_at TEXT,
        deleted_at TEXT
      )
    ''');

    await db.execute(
      "CREATE UNIQUE INDEX idx_chunky_tasks_world_unique_active ON chunky_tasks(world) WHERE deleted_at IS NULL",
    );
    await db.execute(
      "CREATE UNIQUE INDEX idx_chunky_tasks_single_running ON chunky_tasks(status) WHERE deleted_at IS NULL AND status = 'running'",
    );
    await db.execute(
      "CREATE UNIQUE INDEX idx_chunky_tasks_single_selected ON chunky_tasks(status) WHERE deleted_at IS NULL AND status = 'selected'",
    );

    await db.insert('schema_migrations', {
      'version': version,
      'executed_at': DateTime.now().toIso8601String(),
    });
  }
}
