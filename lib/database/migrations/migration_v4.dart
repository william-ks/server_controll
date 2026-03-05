import 'migration.dart';

class MigrationV4 implements Migration {
  @override
  int get version => 4;

  @override
  Future<void> up(dynamic db) async {
    await db.execute(
      "ALTER TABLE schedules ADD COLUMN title TEXT NOT NULL DEFAULT ''",
    );

    await db.insert('schema_migrations', {
      'version': version,
      'executed_at': DateTime.now().toIso8601String(),
    });
  }
}
