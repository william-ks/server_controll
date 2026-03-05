import '../../../database/app_database.dart';
import '../models/schedule_item.dart';

class SchedulesRepository {
  Future<List<ScheduleItem>> getAll() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('schedules', orderBy: 'created_at DESC');
    return rows.map(ScheduleItem.fromMap).toList();
  }

  Future<int> insert(ScheduleItem schedule) async {
    final db = await AppDatabase.instance.database;
    return db.insert('schedules', schedule.toMap());
  }

  Future<void> update(ScheduleItem schedule) async {
    final id = schedule.id;
    if (id == null) return;
    final db = await AppDatabase.instance.database;
    await db.update(
      'schedules',
      schedule.toMap(),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> delete(int id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('schedules', where: 'id = ?', whereArgs: [id]);
  }
}
