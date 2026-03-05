import '../../../database/app_database.dart';
import '../models/chunky_task.dart';
import '../models/chunky_task_status.dart';

class ChunkyTasksRepository {
  Future<List<ChunkyTask>> getAllActive() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'chunky_tasks',
      where: 'deleted_at IS NULL',
      orderBy: 'created_at DESC',
    );
    return rows.map(ChunkyTask.fromMap).toList();
  }

  Future<int> insert(ChunkyTask task) async {
    final db = await AppDatabase.instance.database;
    return db.insert('chunky_tasks', task.toMap());
  }

  Future<void> update(ChunkyTask task) async {
    final id = task.id;
    if (id == null) return;
    final db = await AppDatabase.instance.database;
    await db.update(
      'chunky_tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<void> softDelete(int id) async {
    final db = await AppDatabase.instance.database;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'chunky_tasks',
      <String, Object?>{'deleted_at': now, 'updated_at': now},
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<void> clearSelectedStatus() async {
    final db = await AppDatabase.instance.database;
    final now = DateTime.now().toIso8601String();
    await db.update('chunky_tasks', <String, Object?>{
      'status': ChunkyTaskStatus.draft.storageValue,
      'updated_at': now,
    }, where: "deleted_at IS NULL AND status = 'selected'");
  }

  Future<void> selectTask(int id) async {
    final db = await AppDatabase.instance.database;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.update('chunky_tasks', <String, Object?>{
        'status': ChunkyTaskStatus.draft.storageValue,
        'updated_at': now,
      }, where: "deleted_at IS NULL AND status = 'selected'");
      await txn.update(
        'chunky_tasks',
        <String, Object?>{
          'status': ChunkyTaskStatus.selected.storageValue,
          'updated_at': now,
        },
        where: 'id = ? AND deleted_at IS NULL',
        whereArgs: <Object?>[id],
      );
    });
  }

  Future<ChunkyTask?> getRunningTask() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'chunky_tasks',
      where: "deleted_at IS NULL AND status = 'running'",
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ChunkyTask.fromMap(rows.first);
  }

  Future<ChunkyTask?> getSelectedTask() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'chunky_tasks',
      where: "deleted_at IS NULL AND status = 'selected'",
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ChunkyTask.fromMap(rows.first);
  }

  bool isUniqueViolation(Object error) {
    return error.toString().toLowerCase().contains('unique');
  }
}
