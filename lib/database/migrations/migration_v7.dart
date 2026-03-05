import 'migration.dart';

class MigrationV7 implements Migration {
  @override
  int get version => 7;

  @override
  Future<void> up(dynamic db) async {
    await db.execute(
      'ALTER TABLE chunky_tasks ADD COLUMN center_x INTEGER NOT NULL DEFAULT 0',
    );
    await db.execute(
      'ALTER TABLE chunky_tasks ADD COLUMN center_z INTEGER NOT NULL DEFAULT 0',
    );

    await db.insert('schema_migrations', {
      'version': version,
      'executed_at': DateTime.now().toIso8601String(),
    });
  }
}
