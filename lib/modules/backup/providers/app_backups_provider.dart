import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/providers/config_files_provider.dart';
import '../../maintenance/providers/maintenance_provider.dart';
import '../../players/providers/player_ban_provider.dart';
import '../../players/providers/player_permissions_provider.dart';
import '../../players/providers/player_playtime_provider.dart';
import '../../players/providers/players_registry_provider.dart';
import '../../schedules/providers/schedules_provider.dart';
import '../models/app_backup_entry.dart';
import '../services/app_backup_service.dart';
import 'app_backup_settings_provider.dart';
import 'backup_config_provider.dart';
import 'backups_provider.dart';

class AppBackupsState {
  const AppBackupsState({
    required this.entries,
    required this.loading,
    required this.running,
    this.error,
  });

  final List<AppBackupEntry> entries;
  final bool loading;
  final bool running;
  final String? error;

  AppBackupsState copyWith({
    List<AppBackupEntry>? entries,
    bool? loading,
    bool? running,
    String? error,
    bool clearError = false,
  }) {
    return AppBackupsState(
      entries: entries ?? this.entries,
      loading: loading ?? this.loading,
      running: running ?? this.running,
      error: clearError ? null : (error ?? this.error),
    );
  }

  factory AppBackupsState.initial() {
    return const AppBackupsState(entries: [], loading: false, running: false);
  }
}

final appBackupServiceProvider = Provider<AppBackupService>(
  (_) => AppBackupService(),
);

final appBackupsProvider =
    NotifierProvider<AppBackupsNotifier, AppBackupsState>(
      AppBackupsNotifier.new,
    );

class AppBackupsNotifier extends Notifier<AppBackupsState> {
  AppBackupService get _service => ref.read(appBackupServiceProvider);

  @override
  AppBackupsState build() {
    Future<void>(() => load());
    return AppBackupsState.initial();
  }

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final entries = await _service.listBackups();
      state = state.copyWith(entries: entries, loading: false);
    } catch (error) {
      state = state.copyWith(loading: false, error: error.toString());
    }
  }

  Future<void> createManualBackup() async {
    state = state.copyWith(running: true, clearError: true);
    try {
      await _service.createAppBackup(automatic: false);
      await load();
      state = state.copyWith(running: false);
    } catch (error) {
      state = state.copyWith(running: false, error: error.toString());
      rethrow;
    }
  }

  Future<void> createAutomaticBackup() async {
    state = state.copyWith(running: true, clearError: true);
    try {
      await _service.createAppBackup(automatic: true);
      await load();
      state = state.copyWith(running: false);
    } catch (error) {
      state = state.copyWith(running: false, error: error.toString());
      rethrow;
    }
  }

  Future<void> importBackup(String sourceZipPath) async {
    state = state.copyWith(running: true, clearError: true);
    try {
      await _service.importAppBackup(sourceZipPath);
      await load();
      state = state.copyWith(running: false);
    } catch (error) {
      state = state.copyWith(running: false, error: error.toString());
      rethrow;
    }
  }

  Future<String> exportBackup({
    required String backupPath,
    required String destinationPath,
  }) async {
    state = state.copyWith(running: true, clearError: true);
    try {
      final path = await _service.exportAppBackup(
        backupPath: backupPath,
        destinationPath: destinationPath,
      );
      state = state.copyWith(running: false);
      return path;
    } catch (error) {
      state = state.copyWith(running: false, error: error.toString());
      rethrow;
    }
  }

  Future<void> restoreBackup(String backupPath) async {
    state = state.copyWith(running: true, clearError: true);
    try {
      await _service.restoreAppBackup(backupPath);
      _reloadPostRestoreProviders();
      await load();
      state = state.copyWith(running: false);
    } catch (error) {
      state = state.copyWith(running: false, error: error.toString());
      rethrow;
    }
  }

  Future<void> deleteBackup(String backupPath) async {
    await _service.deleteBackup(backupPath);
    await load();
  }

  void _reloadPostRestoreProviders() {
    ref.invalidate(configFilesProvider);
    ref.invalidate(backupConfigProvider);
    ref.invalidate(appBackupSettingsProvider);
    ref.invalidate(backupsProvider);
    ref.invalidate(schedulesProvider);
    ref.invalidate(maintenanceProvider);
    ref.invalidate(playersRegistryProvider);
    ref.invalidate(playerPermissionsProvider);
    ref.invalidate(playerPlaytimeProvider);
    ref.invalidate(playerBanProvider);
  }
}
