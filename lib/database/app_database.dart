import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'migrations/migration_runner.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<void> initializeDesktop() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  Future<Database> get database async {
    if (_db != null) {
      return _db!;
    }

    final baseDir = await getApplicationSupportDirectory();
    await baseDir.create(recursive: true);
    final dbPath = p.join(baseDir.path, 'minecontrol.db');

    _db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: MigrationRunner.latestVersion,
        onCreate: (db, _) async {
          for (final migration in MigrationRunner.all) {
            await migration.up(db);
          }
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          for (final migration in MigrationRunner.all) {
            if (migration.version > oldVersion && migration.version <= newVersion) {
              await migration.up(db);
            }
          }
        },
      ),
    );

    return _db!;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert('app_settings', {
      'key': key,
      'value': value,
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final rows = await db.query('app_settings', where: 'key = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['value'] as String;
  }

  Future<void> resetDatabase() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }

    final baseDir = await getApplicationSupportDirectory();
    final dbFile = File(p.join(baseDir.path, 'minecontrol.db'));
    if (await dbFile.exists()) {
      await dbFile.delete();
    }
  }
}

