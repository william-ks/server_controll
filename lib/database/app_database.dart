import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();
  static const int _schemaVersion = 8;

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
        version: _schemaVersion,
        onCreate: (db, _) async {
          await _createDefinitiveSchema(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          await _upgradeToDefinitiveSchema(
            db,
            oldVersion: oldVersion,
            newVersion: newVersion,
          );
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
    final rows = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
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

  Future<void> _createDefinitiveSchema(dynamic db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS whitelist_players (
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

    await db.execute('''
      CREATE TABLE IF NOT EXISTS schedules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cron_expression TEXT NOT NULL,
        action TEXT NOT NULL,
        with_backup INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        last_executed_at TEXT,
        title TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS chunky_logs (
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

    await db.execute('''
      CREATE TABLE IF NOT EXISTS chunky_tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        world TEXT NOT NULL,
        radius REAL NOT NULL,
        shape TEXT NOT NULL,
        pattern TEXT NOT NULL,
        backup_before_start INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'draft',
        has_ever_started INTEGER NOT NULL DEFAULT 0,
        center_x INTEGER NOT NULL DEFAULT 0,
        center_z INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        last_run_at TEXT,
        deleted_at TEXT
      )
    ''');

    await db.execute(
      "CREATE UNIQUE INDEX IF NOT EXISTS idx_chunky_tasks_world_unique_active ON chunky_tasks(world) WHERE deleted_at IS NULL",
    );
    await db.execute(
      "CREATE UNIQUE INDEX IF NOT EXISTS idx_chunky_tasks_single_running ON chunky_tasks(status) WHERE deleted_at IS NULL AND status = 'running'",
    );
    await db.execute(
      "CREATE UNIQUE INDEX IF NOT EXISTS idx_chunky_tasks_single_selected ON chunky_tasks(status) WHERE deleted_at IS NULL AND status = 'selected'",
    );
  }

  Future<void> _upgradeToDefinitiveSchema(
    dynamic db, {
    required int oldVersion,
    required int newVersion,
  }) async {
    if (oldVersion == newVersion) return;

    await _createDefinitiveSchema(db);

    await _addColumnIfMissing(
      db,
      table: 'schedules',
      column: 'title',
      definition: "TEXT NOT NULL DEFAULT ''",
    );
    await _addColumnIfMissing(
      db,
      table: 'chunky_tasks',
      column: 'center_x',
      definition: 'INTEGER NOT NULL DEFAULT 0',
    );
    await _addColumnIfMissing(
      db,
      table: 'chunky_tasks',
      column: 'center_z',
      definition: 'INTEGER NOT NULL DEFAULT 0',
    );
  }

  Future<void> _addColumnIfMissing(
    dynamic db, {
    required String table,
    required String column,
    required String definition,
  }) async {
    final info = await db.rawQuery('PRAGMA table_info($table)');
    final exists = info.any((row) => row['name'] == column);
    if (exists) return;
    await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
  }
}
