import '../../../database/app_database.dart';

class ChunkyConfigSettings {
  const ChunkyConfigSettings({
    required this.centerX,
    required this.centerZ,
    required this.radius,
    required this.pattern,
    required this.shape,
    required this.maxChunksPerRun,
    required this.backupBeforeStart,
    required this.radiusMode,
  });

  final String centerX;
  final String centerZ;
  final String radius;
  final String pattern;
  final String shape;
  final String maxChunksPerRun;
  final bool backupBeforeStart;
  final String radiusMode;

  factory ChunkyConfigSettings.defaults() {
    return const ChunkyConfigSettings(
      centerX: '0',
      centerZ: '0',
      radius: '1000',
      pattern: 'spiral',
      shape: 'square',
      maxChunksPerRun: '1000',
      backupBeforeStart: false,
      radiusMode: 'auto',
    );
  }

  static Future<ChunkyConfigSettings> fromDatabase(AppDatabase db) async {
    final defaults = ChunkyConfigSettings.defaults();
    return ChunkyConfigSettings(
      centerX: await db.getSetting('chunk_center_x') ?? defaults.centerX,
      centerZ: await db.getSetting('chunk_center_z') ?? defaults.centerZ,
      radius: await db.getSetting('chunk_radius') ?? defaults.radius,
      pattern: await db.getSetting('chunk_pattern') ?? defaults.pattern,
      shape: await db.getSetting('chunk_shape') ?? defaults.shape,
      maxChunksPerRun:
          await db.getSetting('chunk_max_per_run') ?? defaults.maxChunksPerRun,
      backupBeforeStart:
          (await db.getSetting('chunk_backup_before_start') ?? '0') == '1',
      radiusMode:
          await db.getSetting('chunk_radius_mode') ?? defaults.radiusMode,
    );
  }
}
