import 'migration.dart';

class MigrationV1 implements Migration {
  @override
  int get version => 1;

  @override
  Future<void> up(dynamic db) async {
    await db.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE schema_migrations (
        version INTEGER PRIMARY KEY,
        executed_at TEXT NOT NULL
      )
    ''');

    await db.insert('schema_migrations', {
      'version': version,
      'executed_at': DateTime.now().toIso8601String(),
    });
  }
}
