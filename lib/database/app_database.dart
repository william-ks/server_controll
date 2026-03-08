import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();
  static const int _schemaVersion = 17;
  static int get schemaVersion => _schemaVersion;

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

  Future<String> resolveDatabasePath() async {
    final baseDir = await getApplicationSupportDirectory();
    await baseDir.create(recursive: true);
    return p.join(baseDir.path, 'minecontrol.db');
  }

  Future<void> closeConnection() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
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
    await closeConnection();

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
        backup_kind TEXT NOT NULL DEFAULT 'full',
        selective_roots TEXT NOT NULL DEFAULT '[]',
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

    await _createPlayersDomainTables(db);
    await _createMaintenanceTables(db);
    await _createBackupMetadataTables(db);
    await _createAutomaticBackupTables(db);
    await _createChatHookTables(db);
    await _createAuditTables(db);
    await _createPermissionTables(db);
    await _createPlayerIdentityTables(db);
    await _createPlayerBanTables(db);
    await _migrateWhitelistIntoPlayers(db);
    await _syncPrimaryIdentityFromPlayers(db);
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
      table: 'schedules',
      column: 'backup_kind',
      definition: "TEXT NOT NULL DEFAULT 'full'",
    );
    await _addColumnIfMissing(
      db,
      table: 'schedules',
      column: 'selective_roots',
      definition: "TEXT NOT NULL DEFAULT '[]'",
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

    await _createPlayersDomainTables(db);
    await _createMaintenanceTables(db);
    await _createBackupMetadataTables(db);
    await _createAutomaticBackupTables(db);
    await _createChatHookTables(db);
    await _createAuditTables(db);
    await _createPermissionTables(db);
    await _createPlayerIdentityTables(db);
    await _createPlayerBanTables(db);

    await _addColumnIfMissing(
      db,
      table: 'players',
      column: 'is_player',
      definition: 'INTEGER NOT NULL DEFAULT 1',
    );
    await _addColumnIfMissing(
      db,
      table: 'players',
      column: 'is_whitelisted',
      definition: 'INTEGER NOT NULL DEFAULT 0',
    );
    await _addColumnIfMissing(
      db,
      table: 'players',
      column: 'is_app_admin',
      definition: 'INTEGER NOT NULL DEFAULT 0',
    );
    await _addColumnIfMissing(
      db,
      table: 'players',
      column: 'is_op',
      definition: 'INTEGER NOT NULL DEFAULT 0',
    );
    await _addColumnIfMissing(
      db,
      table: 'players',
      column: 'is_banned',
      definition: 'INTEGER NOT NULL DEFAULT 0',
    );
    await _addColumnIfMissing(
      db,
      table: 'player_bans',
      column: 'pending_ban',
      definition: 'INTEGER NOT NULL DEFAULT 0',
    );

    await _migrateWhitelistIntoPlayers(db);
    await _syncPrimaryIdentityFromPlayers(db);
  }

  Future<void> _createPlayersDomainTables(dynamic db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS players (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nickname TEXT NOT NULL,
        uuid TEXT,
        is_player INTEGER NOT NULL DEFAULT 1,
        is_whitelisted INTEGER NOT NULL DEFAULT 0,
        is_app_admin INTEGER NOT NULL DEFAULT 0,
        is_op INTEGER NOT NULL DEFAULT 0,
        is_banned INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        CHECK (is_op = 0 OR is_app_admin = 1)
      )
    ''');

    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_players_nickname_unique ON players(LOWER(nickname))',
    );
    await db.execute(
      "CREATE UNIQUE INDEX IF NOT EXISTS idx_players_uuid_unique_non_empty ON players(uuid) WHERE uuid IS NOT NULL AND uuid <> ''",
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS player_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        player_id INTEGER NOT NULL,
        is_open INTEGER NOT NULL DEFAULT 1,
        is_incomplete INTEGER NOT NULL DEFAULT 0,
        start_at TEXT NOT NULL,
        end_at TEXT,
        last_seen_at TEXT,
        close_reason TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_player_sessions_player_start ON player_sessions(player_id, start_at)',
    );
    await db.execute(
      "CREATE INDEX IF NOT EXISTS idx_player_sessions_open_only ON player_sessions(player_id) WHERE is_open = 1",
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS player_playtime_aggregates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        player_id INTEGER NOT NULL,
        period_type TEXT NOT NULL,
        period_key TEXT NOT NULL,
        total_seconds INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_playtime_agg_unique_period ON player_playtime_aggregates(player_id, period_type, period_key)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_playtime_agg_type_key ON player_playtime_aggregates(period_type, period_key)',
    );
  }

  Future<void> _createMaintenanceTables(dynamic db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS maintenance_state (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        is_active INTEGER NOT NULL DEFAULT 0,
        mode TEXT NOT NULL DEFAULT 'total',
        starts_at TEXT,
        ends_at TEXT,
        countdown_seconds INTEGER NOT NULL DEFAULT 0,
        motd_before TEXT,
        motd_during TEXT,
        icon_before_path TEXT,
        icon_during_path TEXT,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.insert('maintenance_state', {
      'id': 1,
      'is_active': 0,
      'mode': 'total',
      'countdown_seconds': 0,
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> _createBackupMetadataTables(dynamic db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS backup_history_metadata (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        backup_name TEXT NOT NULL UNIQUE,
        trigger TEXT NOT NULL,
        content_kind TEXT NOT NULL,
        summary_text TEXT,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createAutomaticBackupTables(dynamic db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS automatic_backup_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        schedule_id INTEGER,
        schedule_title TEXT,
        schedule_action TEXT NOT NULL,
        backup_kind TEXT NOT NULL,
        attempt_number INTEGER NOT NULL DEFAULT 1,
        result_status TEXT NOT NULL,
        message TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_auto_backup_history_created ON automatic_backup_history(created_at DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_auto_backup_history_status ON automatic_backup_history(result_status, created_at DESC)',
    );
  }

  Future<void> _createChatHookTables(dynamic db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS chat_hook_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        player TEXT NOT NULL,
        raw_command TEXT NOT NULL,
        parsed_command TEXT,
        parsed_args TEXT NOT NULL DEFAULT '[]',
        permission_applied TEXT NOT NULL,
        result_status TEXT NOT NULL,
        result_message TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_chat_hook_history_created ON chat_hook_history(created_at DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_chat_hook_history_player ON chat_hook_history(LOWER(player), created_at DESC)',
    );
  }

  Future<void> _createAuditTables(dynamic db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS audit_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        event_type TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id TEXT,
        actor_type TEXT NOT NULL,
        actor_id TEXT,
        payload_json TEXT NOT NULL DEFAULT '{}',
        result_status TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_audit_events_created ON audit_events(created_at DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_audit_events_type ON audit_events(event_type, created_at DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_audit_events_actor ON audit_events(actor_id, created_at DESC)',
    );
  }

  Future<void> _createPermissionTables(dynamic db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS permission_pending_actions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        player_id INTEGER NOT NULL,
        nickname TEXT NOT NULL,
        action_type TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        error_message TEXT,
        created_at TEXT NOT NULL,
        applied_at TEXT,
        FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      "CREATE INDEX IF NOT EXISTS idx_permission_pending_status ON permission_pending_actions(status, created_at)",
    );
  }

  Future<void> _createPlayerIdentityTables(dynamic db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS player_identities (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        player_id INTEGER NOT NULL,
        nickname TEXT NOT NULL,
        uuid TEXT,
        is_primary INTEGER NOT NULL DEFAULT 1,
        conflict_pending_manual_review INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      "CREATE UNIQUE INDEX IF NOT EXISTS idx_player_identities_uuid_unique_non_empty ON player_identities(uuid) WHERE uuid IS NOT NULL AND uuid <> ''",
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_player_identities_player ON player_identities(player_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_player_identities_nickname ON player_identities(LOWER(nickname))',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS player_status_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        player_id INTEGER NOT NULL,
        status_type TEXT NOT NULL,
        old_value TEXT,
        new_value TEXT,
        changed_by TEXT NOT NULL DEFAULT 'system',
        note TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_player_status_history_player ON player_status_history(player_id, created_at DESC)',
    );
  }

  Future<void> _migrateWhitelistIntoPlayers(dynamic db) async {
    await db.execute('''
      INSERT OR IGNORE INTO players (
        nickname,
        uuid,
        is_player,
        is_whitelisted,
        created_at,
        updated_at
      )
      SELECT
        w.nickname,
        w.uuid,
        1,
        1,
        w.created_at,
        w.updated_at
      FROM whitelist_players w
      WHERE TRIM(w.nickname) <> ''
    ''');

    await db.execute('''
      UPDATE players
      SET
        is_whitelisted = CASE
          WHEN LOWER(nickname) IN (
            SELECT LOWER(nickname) FROM whitelist_players WHERE TRIM(nickname) <> ''
          ) THEN 1
          ELSE is_whitelisted
        END,
        updated_at = updated_at
    ''');
  }

  Future<void> _syncPrimaryIdentityFromPlayers(dynamic db) async {
    final rows = await db.query(
      'players',
      columns: ['id', 'nickname', 'uuid', 'created_at', 'updated_at'],
    );

    for (final row in rows) {
      final playerId = row['id'] as int? ?? 0;
      final nickname = (row['nickname'] as String? ?? '').trim();
      if (playerId <= 0 || nickname.isEmpty) continue;

      final createdAt =
          (row['created_at'] as String?) ?? DateTime.now().toIso8601String();
      final updatedAt =
          (row['updated_at'] as String?) ?? DateTime.now().toIso8601String();
      final uuid = (row['uuid'] as String?)?.trim();

      await db.insert('player_identities', {
        'player_id': playerId,
        'nickname': nickname,
        'uuid': uuid == null || uuid.isEmpty ? null : uuid,
        'is_primary': 1,
        'conflict_pending_manual_review': 0,
        'created_at': createdAt,
        'updated_at': updatedAt,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _createPlayerBanTables(dynamic db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS player_bans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        player_id INTEGER NOT NULL,
        reason TEXT,
        starts_at TEXT NOT NULL,
        expires_at TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        pending_ban INTEGER NOT NULL DEFAULT 0,
        pending_unban INTEGER NOT NULL DEFAULT 0,
        created_by TEXT NOT NULL DEFAULT 'app',
        removed_by TEXT,
        removed_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_player_bans_active ON player_bans(player_id, is_active)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_player_bans_expiration ON player_bans(is_active, expires_at)',
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
