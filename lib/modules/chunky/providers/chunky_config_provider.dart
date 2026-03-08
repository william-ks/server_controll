import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../models/chunky_backup_kind.dart';
import '../models/chunky_config_settings.dart';

final chunkyConfigInitialProvider = Provider<ChunkyConfigSettings>((_) {
  return ChunkyConfigSettings.defaults();
});

final chunkyConfigProvider =
    NotifierProvider<ChunkyConfigNotifier, ChunkyConfigSettings>(
      ChunkyConfigNotifier.new,
    );

class ChunkyConfigNotifier extends Notifier<ChunkyConfigSettings> {
  @override
  ChunkyConfigSettings build() {
    Future<void>(() => loadFromDb());
    return ref.watch(chunkyConfigInitialProvider);
  }

  Future<void> loadFromDb() async {
    state = await ChunkyConfigSettings.fromDatabase(AppDatabase.instance);
  }

  Future<void> save(ChunkyConfigSettings settings) async {
    final db = AppDatabase.instance;
    await db.setSetting('chunk_center_x', settings.centerX);
    await db.setSetting('chunk_center_z', settings.centerZ);
    await db.setSetting('chunk_radius', settings.radius);
    await db.setSetting('chunk_pattern', settings.pattern);
    await db.setSetting('chunk_shape', settings.shape);
    await db.setSetting('chunk_max_per_run', settings.maxChunksPerRun);
    await db.setSetting(
      'chunk_backup_before_start',
      settings.backupBeforeStart ? '1' : '0',
    );
    await db.setSetting('chunk_backup_kind', settings.backupKind.storageValue);
    await db.setSetting(
      'chunk_backup_selective_roots',
      settings.backupSelectiveRoots.join(','),
    );
    await db.setSetting('chunk_radius_mode', settings.radiusMode);
    state = settings;
  }
}
