import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chunky_task.dart';
import '../models/chunky_task_status.dart';
import '../repositories/chunky_tasks_repository.dart';

class ChunkyTasksState {
  const ChunkyTasksState({
    required this.items,
    required this.loading,
    this.error,
  });

  final List<ChunkyTask> items;
  final bool loading;
  final String? error;

  ChunkyTask? get selectedTask {
    for (final item in items) {
      if (item.status == ChunkyTaskStatus.selected) {
        return item;
      }
    }
    for (final item in items) {
      if (item.status == ChunkyTaskStatus.running ||
          item.status == ChunkyTaskStatus.paused) {
        return item;
      }
    }
    return null;
  }

  ChunkyTask? get runningTask {
    for (final item in items) {
      if (item.status == ChunkyTaskStatus.running) {
        return item;
      }
    }
    return null;
  }

  ChunkyTasksState copyWith({
    List<ChunkyTask>? items,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return ChunkyTasksState(
      items: items ?? this.items,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  factory ChunkyTasksState.initial() {
    return const ChunkyTasksState(items: <ChunkyTask>[], loading: false);
  }
}

final chunkyTasksRepositoryProvider = Provider<ChunkyTasksRepository>(
  (_) => ChunkyTasksRepository(),
);

final chunkyTasksProvider =
    NotifierProvider<ChunkyTasksNotifier, ChunkyTasksState>(
      ChunkyTasksNotifier.new,
    );

class ChunkyTasksNotifier extends Notifier<ChunkyTasksState> {
  ChunkyTasksRepository get _repository =>
      ref.read(chunkyTasksRepositoryProvider);

  @override
  ChunkyTasksState build() {
    Future<void>(() => load());
    return ChunkyTasksState.initial();
  }

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final items = await _repository.getAllActive();
      state = state.copyWith(items: items, loading: false);
    } catch (error) {
      state = state.copyWith(loading: false, error: error.toString());
    }
  }

  Future<void> create({
    required String name,
    required String world,
    required int centerX,
    required int centerZ,
    required double radius,
    required String shape,
    required String pattern,
    required bool backupBeforeStart,
  }) async {
    final now = DateTime.now();
    final item = ChunkyTask(
      name: name.trim(),
      world: world.trim(),
      centerX: centerX,
      centerZ: centerZ,
      radius: radius,
      shape: shape.trim(),
      pattern: pattern.trim(),
      backupBeforeStart: backupBeforeStart,
      status: ChunkyTaskStatus.draft,
      hasEverStarted: false,
      createdAt: now,
      updatedAt: now,
    );
    try {
      await _repository.insert(item);
      await load();
    } catch (error) {
      if (_repository.isUniqueViolation(error)) {
        throw StateError('Já existe uma task para este world.');
      }
      rethrow;
    }
  }

  Future<void> updateTask(ChunkyTask item) async {
    if (item.id == null) return;
    if (item.hasEverStarted) {
      throw StateError(
        'This task has already been started and can\'t be modified.',
      );
    }
    try {
      await _repository.update(item.copyWith(updatedAt: DateTime.now()));
      await load();
    } catch (error) {
      if (_repository.isUniqueViolation(error)) {
        throw StateError('Já existe uma task para este world.');
      }
      rethrow;
    }
  }

  Future<void> deleteTask(int id) async {
    await _repository.softDelete(id);
    await load();
  }

  Future<void> selectTask(int id) async {
    final running = state.runningTask;
    if (running != null && running.id != id) {
      throw StateError(
        'Existe uma task em execução. Pause/cancele antes de selecionar outra.',
      );
    }
    await _repository.selectTask(id);
    await load();
  }

  Future<void> clearSelected() async {
    await _repository.clearSelectedStatus();
    await load();
  }

  Future<void> markRunning(int id) async {
    final now = DateTime.now();
    final current = _findById(id);
    if (current == null) return;
    await _repository.update(
      current.copyWith(
        status: ChunkyTaskStatus.running,
        hasEverStarted: true,
        lastRunAt: now,
        updatedAt: now,
      ),
    );
    await load();
  }

  Future<void> markPaused(int id) async {
    final current = _findById(id);
    if (current == null) return;
    await _repository.update(
      current.copyWith(
        status: ChunkyTaskStatus.paused,
        updatedAt: DateTime.now(),
      ),
    );
    await load();
  }

  Future<void> markCompleted(int id) async {
    final current = _findById(id);
    if (current == null) return;
    await _repository.update(
      current.copyWith(
        status: ChunkyTaskStatus.completed,
        updatedAt: DateTime.now(),
      ),
    );
    await load();
  }

  Future<void> markCancelled(int id) async {
    final current = _findById(id);
    if (current == null) return;
    await _repository.update(
      current.copyWith(
        status: ChunkyTaskStatus.cancelled,
        updatedAt: DateTime.now(),
      ),
    );
    await load();
  }

  ChunkyTask? _findById(int id) {
    for (final item in state.items) {
      if (item.id == id) return item;
    }
    return null;
  }
}
