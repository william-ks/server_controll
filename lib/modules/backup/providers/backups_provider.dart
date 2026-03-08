import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audit/services/audit_service.dart';
import '../../../modules/config/providers/config_files_provider.dart';
import '../../../modules/server/providers/server_runtime_provider.dart';
import '../../../models/server_lifecycle_state.dart';
import '../models/backup_capacity_status.dart';
import '../models/backup_entry.dart';
import '../services/backup_service.dart';
import '../services/backup_restore_service.dart';
import 'backup_config_provider.dart';

class BackupsState {
  const BackupsState({
    required this.entries,
    required this.capacity,
    required this.loading,
    required this.creating,
    this.error,
  });

  final List<BackupEntry> entries;
  final BackupCapacityStatus? capacity;
  final bool loading;
  final bool creating;
  final String? error;

  BackupsState copyWith({
    List<BackupEntry>? entries,
    BackupCapacityStatus? capacity,
    bool? loading,
    bool? creating,
    String? error,
    bool clearError = false,
  }) {
    return BackupsState(
      entries: entries ?? this.entries,
      capacity: capacity ?? this.capacity,
      loading: loading ?? this.loading,
      creating: creating ?? this.creating,
      error: clearError ? null : (error ?? this.error),
    );
  }

  factory BackupsState.initial() {
    return const BackupsState(
      entries: [],
      capacity: null,
      loading: false,
      creating: false,
    );
  }
}

final backupServiceProvider = Provider<BackupService>((_) => BackupService());
final backupRestoreServiceProvider = Provider<BackupRestoreService>((ref) {
  return BackupRestoreService(backupService: ref.read(backupServiceProvider));
});

final backupsProvider = NotifierProvider<BackupsNotifier, BackupsState>(
  BackupsNotifier.new,
);

class BackupsNotifier extends Notifier<BackupsState> {
  BackupService get _service => ref.read(backupServiceProvider);
  BackupRestoreService get _restoreService =>
      ref.read(backupRestoreServiceProvider);

  @override
  BackupsState build() {
    Future<void>(() => load());
    return BackupsState.initial();
  }

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final config = ref.read(backupConfigProvider);
      final entries = await _service.listBackups(config);
      final capacity = await _service.evaluateCapacity(config);
      state = state.copyWith(
        entries: entries,
        capacity: capacity,
        loading: false,
      );
    } catch (error) {
      state = state.copyWith(loading: false, error: error.toString());
    }
  }

  Future<void> createManualBackup() async {
    final runtime = ref.read(serverRuntimeProvider);
    if (runtime.lifecycle != ServerLifecycleState.offline) {
      throw StateError('Servidor precisa estar OFFLINE para executar backup.');
    }

    state = state.copyWith(creating: true, clearError: true);
    try {
      final configFiles = ref.read(configFilesProvider);
      final backupConfig = ref.read(backupConfigProvider);
      await _service.createBackup(
        serverPath: configFiles.serverPath.trim(),
        config: backupConfig,
        trigger: BackupTriggerType.manual,
        kind: BackupContentKind.full,
      );
      final entries = await _service.listBackups(backupConfig);
      final capacity = await _service.evaluateCapacity(backupConfig);
      state = state.copyWith(
        entries: entries,
        capacity: capacity,
        creating: false,
      );
      await ref
          .read(auditServiceProvider)
          .logEvent(
            eventType: 'backup.manual',
            entityType: 'server_backup',
            actorType: 'app_operator',
            payload: {'kind': 'full'},
            resultStatus: 'success',
          );
    } catch (error) {
      state = state.copyWith(creating: false, error: error.toString());
      await ref
          .read(auditServiceProvider)
          .logEvent(
            eventType: 'backup.manual',
            entityType: 'server_backup',
            actorType: 'app_operator',
            payload: {'kind': 'full', 'error': error.toString()},
            resultStatus: 'error',
          );
      rethrow;
    }
  }

  Future<void> createManualBackupWithController(
    BackupTaskController controller, {
    BackupContentKind kind = BackupContentKind.full,
    List<String> selectiveRootEntries = const [],
  }) async {
    final runtime = ref.read(serverRuntimeProvider);
    if (runtime.lifecycle != ServerLifecycleState.offline) {
      throw StateError('Servidor precisa estar OFFLINE para executar backup.');
    }
    if (kind == BackupContentKind.selective && selectiveRootEntries.isEmpty) {
      throw StateError('Selecione ao menos um item da raiz para o backup.');
    }

    state = state.copyWith(creating: true, clearError: true);
    try {
      final configFiles = ref.read(configFilesProvider);
      final backupConfig = ref.read(backupConfigProvider);
      final summary = selectiveRootEntries.join(', ');
      await _service.createBackup(
        serverPath: configFiles.serverPath.trim(),
        config: backupConfig,
        trigger: BackupTriggerType.manual,
        kind: kind,
        selectiveRootEntries: selectiveRootEntries,
        selectiveSummary: kind == BackupContentKind.selective ? summary : null,
        controller: controller,
      );
      final entries = await _service.listBackups(backupConfig);
      final capacity = await _service.evaluateCapacity(backupConfig);
      state = state.copyWith(
        entries: entries,
        capacity: capacity,
        creating: false,
      );
      await ref
          .read(auditServiceProvider)
          .logEvent(
            eventType: 'backup.manual',
            entityType: 'server_backup',
            actorType: 'app_operator',
            payload: {
              'kind': kind.name,
              if (kind == BackupContentKind.selective)
                'entries': selectiveRootEntries,
            },
            resultStatus: 'success',
          );
    } catch (error) {
      state = state.copyWith(creating: false, error: error.toString());
      await ref
          .read(auditServiceProvider)
          .logEvent(
            eventType: 'backup.manual',
            entityType: 'server_backup',
            actorType: 'app_operator',
            payload: {
              'kind': kind.name,
              if (kind == BackupContentKind.selective)
                'entries': selectiveRootEntries,
              'error': error.toString(),
            },
            resultStatus: 'error',
          );
      rethrow;
    }
  }

  Future<void> createManualWorldBackup() async {
    final runtime = ref.read(serverRuntimeProvider);
    if (runtime.lifecycle != ServerLifecycleState.offline) {
      throw StateError('Servidor precisa estar OFFLINE para executar backup.');
    }

    state = state.copyWith(creating: true, clearError: true);
    try {
      final configFiles = ref.read(configFilesProvider);
      final backupConfig = ref.read(backupConfigProvider);
      await _service.createBackup(
        serverPath: configFiles.serverPath.trim(),
        config: backupConfig,
        trigger: BackupTriggerType.manual,
        kind: BackupContentKind.world,
      );
      final entries = await _service.listBackups(backupConfig);
      final capacity = await _service.evaluateCapacity(backupConfig);
      state = state.copyWith(
        entries: entries,
        capacity: capacity,
        creating: false,
      );
      await ref
          .read(auditServiceProvider)
          .logEvent(
            eventType: 'backup.manual',
            entityType: 'server_backup',
            actorType: 'app_operator',
            payload: {'kind': 'world'},
            resultStatus: 'success',
          );
    } catch (error) {
      state = state.copyWith(creating: false, error: error.toString());
      await ref
          .read(auditServiceProvider)
          .logEvent(
            eventType: 'backup.manual',
            entityType: 'server_backup',
            actorType: 'app_operator',
            payload: {'kind': 'world', 'error': error.toString()},
            resultStatus: 'error',
          );
      rethrow;
    }
  }

  Future<void> createManualSelectiveBackup(List<String> rootEntries) async {
    final runtime = ref.read(serverRuntimeProvider);
    if (runtime.lifecycle != ServerLifecycleState.offline) {
      throw StateError('Servidor precisa estar OFFLINE para executar backup.');
    }
    if (rootEntries.isEmpty) {
      throw StateError('Selecione ao menos um item da raiz para o backup.');
    }

    state = state.copyWith(creating: true, clearError: true);
    try {
      final configFiles = ref.read(configFilesProvider);
      final backupConfig = ref.read(backupConfigProvider);
      final summary = rootEntries.join(', ');
      await _service.createBackup(
        serverPath: configFiles.serverPath.trim(),
        config: backupConfig,
        trigger: BackupTriggerType.manual,
        kind: BackupContentKind.selective,
        selectiveRootEntries: rootEntries,
        selectiveSummary: summary,
      );
      final entries = await _service.listBackups(backupConfig);
      final capacity = await _service.evaluateCapacity(backupConfig);
      state = state.copyWith(
        entries: entries,
        capacity: capacity,
        creating: false,
      );
      await ref
          .read(auditServiceProvider)
          .logEvent(
            eventType: 'backup.manual',
            entityType: 'server_backup',
            actorType: 'app_operator',
            payload: {'kind': 'selective', 'entries': rootEntries},
            resultStatus: 'success',
          );
    } catch (error) {
      state = state.copyWith(creating: false, error: error.toString());
      await ref
          .read(auditServiceProvider)
          .logEvent(
            eventType: 'backup.manual',
            entityType: 'server_backup',
            actorType: 'app_operator',
            payload: {
              'kind': 'selective',
              'entries': rootEntries,
              'error': error.toString(),
            },
            resultStatus: 'error',
          );
      rethrow;
    }
  }

  Future<void> deleteBackup(String filePath) async {
    await _service.deleteBackup(filePath);
    await load();
  }

  Future<void> restoreWorldBackup(String filePath) async {
    final runtime = ref.read(serverRuntimeProvider);
    if (runtime.lifecycle != ServerLifecycleState.offline) {
      throw StateError('Restauração exige servidor OFFLINE.');
    }
    if (runtime.activePlayers > 0) {
      throw StateError(
        'Existem players ativos. Pare o servidor corretamente antes de restaurar.',
      );
    }

    state = state.copyWith(creating: true, clearError: true);
    try {
      final configFiles = ref.read(configFilesProvider);
      final backupConfig = ref.read(backupConfigProvider);
      await _restoreService.restoreWorld(
        backupZipPath: filePath,
        serverPath: configFiles.serverPath.trim(),
        backupConfig: backupConfig,
        isServerOffline: runtime.lifecycle == ServerLifecycleState.offline,
        activePlayers: runtime.activePlayers,
      );
      await load();
      state = state.copyWith(creating: false);
      await ref
          .read(auditServiceProvider)
          .logEvent(
            eventType: 'backup.restore',
            entityType: 'server_backup',
            actorType: 'app_operator',
            payload: {'kind': 'world', 'backup_path': filePath},
            resultStatus: 'success',
          );
    } catch (error) {
      state = state.copyWith(creating: false, error: error.toString());
      await ref
          .read(auditServiceProvider)
          .logEvent(
            eventType: 'backup.restore',
            entityType: 'server_backup',
            actorType: 'app_operator',
            payload: {
              'kind': 'world',
              'backup_path': filePath,
              'error': error.toString(),
            },
            resultStatus: 'error',
          );
      rethrow;
    }
  }

  Future<void> restoreFullBackup(String filePath) async {
    final runtime = ref.read(serverRuntimeProvider);
    if (runtime.lifecycle != ServerLifecycleState.offline) {
      throw StateError('Restauração exige servidor OFFLINE.');
    }
    if (runtime.activePlayers > 0) {
      throw StateError(
        'Existem players ativos. Pare o servidor corretamente antes de restaurar.',
      );
    }

    state = state.copyWith(creating: true, clearError: true);
    try {
      final configFiles = ref.read(configFilesProvider);
      final backupConfig = ref.read(backupConfigProvider);
      await _restoreService.restoreFull(
        backupZipPath: filePath,
        serverPath: configFiles.serverPath.trim(),
        backupConfig: backupConfig,
        isServerOffline: runtime.lifecycle == ServerLifecycleState.offline,
        activePlayers: runtime.activePlayers,
      );
      await load();
      state = state.copyWith(creating: false);
      await ref
          .read(auditServiceProvider)
          .logEvent(
            eventType: 'backup.restore',
            entityType: 'server_backup',
            actorType: 'app_operator',
            payload: {'kind': 'full', 'backup_path': filePath},
            resultStatus: 'success',
          );
    } catch (error) {
      state = state.copyWith(creating: false, error: error.toString());
      await ref
          .read(auditServiceProvider)
          .logEvent(
            eventType: 'backup.restore',
            entityType: 'server_backup',
            actorType: 'app_operator',
            payload: {
              'kind': 'full',
              'backup_path': filePath,
              'error': error.toString(),
            },
            resultStatus: 'error',
          );
      rethrow;
    }
  }
}
