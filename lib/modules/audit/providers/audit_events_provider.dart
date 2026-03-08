import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/audit_event.dart';
import '../services/audit_service.dart';

enum AuditDateFilter { today, last7Days, last30Days, all }

extension AuditDateFilterX on AuditDateFilter {
  String get label => switch (this) {
    AuditDateFilter.today => 'Hoje',
    AuditDateFilter.last7Days => 'Últimos 7 dias',
    AuditDateFilter.last30Days => 'Últimos 30 dias',
    AuditDateFilter.all => 'Todo período',
  };
}

class AuditEventsState {
  const AuditEventsState({
    required this.events,
    required this.loading,
    required this.dateFilter,
    required this.eventTypeFilter,
    required this.playerFilter,
    required this.actionFilter,
    this.error,
  });

  final List<AuditEvent> events;
  final bool loading;
  final AuditDateFilter dateFilter;
  final String eventTypeFilter;
  final String playerFilter;
  final String actionFilter;
  final String? error;

  AuditEventsState copyWith({
    List<AuditEvent>? events,
    bool? loading,
    AuditDateFilter? dateFilter,
    String? eventTypeFilter,
    String? playerFilter,
    String? actionFilter,
    String? error,
    bool clearError = false,
  }) {
    return AuditEventsState(
      events: events ?? this.events,
      loading: loading ?? this.loading,
      dateFilter: dateFilter ?? this.dateFilter,
      eventTypeFilter: eventTypeFilter ?? this.eventTypeFilter,
      playerFilter: playerFilter ?? this.playerFilter,
      actionFilter: actionFilter ?? this.actionFilter,
      error: clearError ? null : (error ?? this.error),
    );
  }

  factory AuditEventsState.initial() {
    return const AuditEventsState(
      events: [],
      loading: false,
      dateFilter: AuditDateFilter.last7Days,
      eventTypeFilter: '',
      playerFilter: '',
      actionFilter: '',
    );
  }
}

final auditEventsProvider =
    NotifierProvider<AuditEventsNotifier, AuditEventsState>(
      AuditEventsNotifier.new,
    );

class AuditEventsNotifier extends Notifier<AuditEventsState> {
  AuditService get _service => ref.read(auditServiceProvider);

  @override
  AuditEventsState build() {
    Future<void>(() => load());
    return AuditEventsState.initial();
  }

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final now = DateTime.now();
      final range = _resolveRange(now, state.dateFilter);
      final events = await _service.listEvents(
        eventType: state.eventTypeFilter.trim().isEmpty
            ? null
            : state.eventTypeFilter.trim(),
        from: range.$1,
        to: range.$2,
        player: state.playerFilter.trim(),
        actionQuery: state.actionFilter.trim(),
      );
      state = state.copyWith(events: events, loading: false);
    } catch (error) {
      state = state.copyWith(loading: false, error: error.toString());
    }
  }

  Future<void> setEventTypeFilter(String value) async {
    state = state.copyWith(eventTypeFilter: value);
    await load();
  }

  Future<void> setDateFilter(AuditDateFilter value) async {
    state = state.copyWith(dateFilter: value);
    await load();
  }

  Future<void> setPlayerFilter(String value) async {
    state = state.copyWith(playerFilter: value);
    await load();
  }

  Future<void> setActionFilter(String value) async {
    state = state.copyWith(actionFilter: value);
    await load();
  }

  (DateTime?, DateTime?) _resolveRange(DateTime now, AuditDateFilter filter) {
    return switch (filter) {
      AuditDateFilter.today => (
        DateTime(now.year, now.month, now.day),
        DateTime(now.year, now.month, now.day, 23, 59, 59),
      ),
      AuditDateFilter.last7Days => (now.subtract(const Duration(days: 7)), now),
      AuditDateFilter.last30Days => (
        now.subtract(const Duration(days: 30)),
        now,
      ),
      AuditDateFilter.all => (null, null),
    };
  }
}
