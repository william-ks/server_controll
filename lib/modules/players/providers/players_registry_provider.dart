import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../models/player_registry_history_event.dart';
import '../models/player_registry_item.dart';

class PlayersRegistryState {
  const PlayersRegistryState({
    required this.loading,
    required this.players,
    required this.history,
    this.error,
  });

  final bool loading;
  final List<PlayerRegistryItem> players;
  final List<PlayerRegistryHistoryEvent> history;
  final String? error;

  PlayersRegistryState copyWith({
    bool? loading,
    List<PlayerRegistryItem>? players,
    List<PlayerRegistryHistoryEvent>? history,
    String? error,
    bool clearError = false,
  }) {
    return PlayersRegistryState(
      loading: loading ?? this.loading,
      players: players ?? this.players,
      history: history ?? this.history,
      error: clearError ? null : (error ?? this.error),
    );
  }

  factory PlayersRegistryState.initial() {
    return const PlayersRegistryState(loading: false, players: [], history: []);
  }
}

final playersRegistryProvider =
    NotifierProvider<PlayersRegistryNotifier, PlayersRegistryState>(
      PlayersRegistryNotifier.new,
    );

class PlayersRegistryNotifier extends Notifier<PlayersRegistryState> {
  @override
  PlayersRegistryState build() {
    Future<void>(() => load());
    return PlayersRegistryState.initial();
  }

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final db = await AppDatabase.instance.database;
      final playersRows = await db.rawQuery('''
        SELECT
          p.id AS id,
          p.nickname AS nickname,
          p.uuid AS uuid,
          p.is_whitelisted AS is_whitelisted,
          p.is_app_admin AS is_app_admin,
          p.is_op AS is_op,
          p.is_banned AS is_banned,
          p.created_at AS created_at,
          p.updated_at AS updated_at,
          COALESCE(MAX(i.conflict_pending_manual_review), 0) AS has_conflict
        FROM players p
        LEFT JOIN player_identities i ON i.player_id = p.id
        GROUP BY p.id
        ORDER BY LOWER(p.nickname) ASC
      ''');

      final players = playersRows.map((row) {
        return PlayerRegistryItem(
          id: row['id'] as int? ?? 0,
          nickname: row['nickname'] as String? ?? '',
          uuid: row['uuid'] as String?,
          isWhitelisted: (row['is_whitelisted'] as int? ?? 0) == 1,
          isAppAdmin: (row['is_app_admin'] as int? ?? 0) == 1,
          isOp: (row['is_op'] as int? ?? 0) == 1,
          isBanned: (row['is_banned'] as int? ?? 0) == 1,
          hasIdentityConflict: (row['has_conflict'] as int? ?? 0) == 1,
          createdAt:
              DateTime.tryParse((row['created_at'] as String?) ?? '') ??
              DateTime.now(),
          updatedAt:
              DateTime.tryParse((row['updated_at'] as String?) ?? '') ??
              DateTime.now(),
        );
      }).toList();

      final historyRows = await db.rawQuery('''
        SELECT
          p.nickname AS nickname,
          h.status_type AS status_type,
          h.old_value AS old_value,
          h.new_value AS new_value,
          h.created_at AS created_at
        FROM player_status_history h
        INNER JOIN players p ON p.id = h.player_id
        ORDER BY h.created_at DESC
        LIMIT 200
      ''');

      final statusHistory = historyRows.map((row) {
        final oldValue = (row['old_value'] as String?) ?? '';
        final newValue = (row['new_value'] as String?) ?? '';
        final eventType = row['status_type'] as String? ?? 'status_change';
        return PlayerRegistryHistoryEvent(
          playerNickname: row['nickname'] as String? ?? '',
          eventType: eventType,
          description: '$eventType: $oldValue -> $newValue',
          createdAt:
              DateTime.tryParse((row['created_at'] as String?) ?? '') ??
              DateTime.now(),
        );
      }).toList();

      final sessionRows = await db.rawQuery('''
        SELECT
          p.nickname AS nickname,
          s.close_reason AS close_reason,
          s.is_incomplete AS is_incomplete,
          s.start_at AS start_at,
          s.end_at AS end_at
        FROM player_sessions s
        INNER JOIN players p ON p.id = s.player_id
        ORDER BY s.start_at DESC
        LIMIT 120
      ''');

      final sessionHistory = sessionRows.map((row) {
        final reason = (row['close_reason'] as String?) ?? 'session';
        final isIncomplete = (row['is_incomplete'] as int? ?? 0) == 1;
        final start = DateTime.tryParse((row['start_at'] as String?) ?? '');
        final end = DateTime.tryParse((row['end_at'] as String?) ?? '');
        final description =
            'sessão ${start != null ? start.toLocal() : '-'} até ${end != null ? end.toLocal() : '-'}'
            '${isIncomplete ? ' (incompleta)' : ''} • motivo: $reason';
        return PlayerRegistryHistoryEvent(
          playerNickname: row['nickname'] as String? ?? '',
          eventType: 'session',
          description: description,
          createdAt: start ?? DateTime.now(),
        );
      }).toList();

      final fullHistory = [...statusHistory, ...sessionHistory]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      state = state.copyWith(
        loading: false,
        players: players,
        history: fullHistory,
      );
    } catch (error) {
      state = state.copyWith(loading: false, error: error.toString());
    }
  }
}
