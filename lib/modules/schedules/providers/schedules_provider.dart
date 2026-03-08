import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audit/services/audit_service.dart';
import '../models/schedule_action.dart';
import '../models/schedule_backup_kind.dart';
import '../models/schedule_item.dart';
import '../repositories/schedules_repository.dart';

class SchedulesState {
  const SchedulesState({
    required this.items,
    required this.loading,
    this.error,
  });

  final List<ScheduleItem> items;
  final bool loading;
  final String? error;

  SchedulesState copyWith({
    List<ScheduleItem>? items,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return SchedulesState(
      items: items ?? this.items,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  factory SchedulesState.initial() =>
      const SchedulesState(items: [], loading: false);
}

final schedulesRepositoryProvider = Provider<SchedulesRepository>(
  (_) => SchedulesRepository(),
);

final schedulesProvider = NotifierProvider<SchedulesNotifier, SchedulesState>(
  SchedulesNotifier.new,
);

class SchedulesNotifier extends Notifier<SchedulesState> {
  SchedulesRepository get _repository => ref.read(schedulesRepositoryProvider);

  @override
  SchedulesState build() {
    Future<void>(() => load());
    return SchedulesState.initial();
  }

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final items = await _repository.getAll();
      state = state.copyWith(items: items, loading: false);
    } catch (error) {
      state = state.copyWith(loading: false, error: error.toString());
    }
  }

  Future<void> create({
    required String title,
    required String cronExpression,
    required ScheduleAction action,
    required bool withBackup,
    required ScheduleBackupKind backupKind,
    required List<String> selectiveRootEntries,
  }) async {
    final now = DateTime.now();
    final item = ScheduleItem(
      title: title.trim(),
      cronExpression: cronExpression.trim(),
      action: action,
      withBackup: withBackup,
      backupKind: backupKind,
      selectiveRootEntries: selectiveRootEntries,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );
    await _repository.insert(item);
    await load();
    await ref
        .read(auditServiceProvider)
        .logEvent(
          eventType: 'admin.schedule',
          entityType: 'schedule',
          actorType: 'app_operator',
          payload: {
            'action': 'create',
            'title': title,
            'cron_expression': cronExpression,
            'schedule_action': action.storageValue,
            'with_backup': withBackup,
            'backup_kind': backupKind.storageValue,
            'selective_entries': selectiveRootEntries,
          },
          resultStatus: 'success',
        );
  }

  Future<void> setActive({
    required ScheduleItem item,
    required bool active,
  }) async {
    await _repository.update(
      item.copyWith(isActive: active, updatedAt: DateTime.now()),
    );
    await load();
  }

  Future<void> markExecuted(int id) async {
    ScheduleItem? current;
    for (final item in state.items) {
      if (item.id == id) {
        current = item;
        break;
      }
    }
    if (current == null) return;

    await _repository.update(
      current.copyWith(
        lastExecutedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    await load();
  }

  Future<void> delete(int id) async {
    await _repository.delete(id);
    await load();
    await ref
        .read(auditServiceProvider)
        .logEvent(
          eventType: 'admin.schedule',
          entityType: 'schedule',
          entityId: '$id',
          actorType: 'app_operator',
          payload: {'action': 'delete', 'id': id},
          resultStatus: 'success',
        );
  }
}
