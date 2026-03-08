import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../players/models/player_playtime_summary.dart';
import '../../players/models/player_session_entry.dart';
import '../../players/providers/player_playtime_provider.dart';

class PlayerPlaytimePanel extends StatelessWidget {
  const PlayerPlaytimePanel({
    super.key,
    required this.state,
    required this.onSelectPlayer,
    required this.onRefresh,
  });

  final PlayerPlaytimeState state;
  final ValueChanged<int> onSelectPlayer;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final ranking = state.ranking;
    final selectedPlayerId = state.selectedPlayerId;
    final selectedHistory = state.selectedHistory;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tempo de jogo dos players',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: state.syncing ? null : onRefresh,
                icon: state.syncing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
                tooltip: 'Atualizar ranking',
              ),
            ],
          ),
          if (ranking.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Sem sessões registradas ainda.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else ...[
            const SizedBox(height: 6),
            Text(
              'Ranking geral (total):',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < ranking.length; i++)
              _RankingTile(
                index: i + 1,
                summary: ranking[i],
                selected: ranking[i].playerId == selectedPlayerId,
                onTap: () => onSelectPlayer(ranking[i].playerId),
              ),
            if (selectedPlayerId != null) ...[
              const SizedBox(height: 12),
              Text(
                'Histórico do player selecionado:',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              if (selectedHistory.isEmpty)
                Text(
                  'Nenhuma sessão para este player.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                )
              else
                for (final session in selectedHistory.take(8))
                  _SessionTile(session: session),
            ],
          ],
        ],
      ),
    );
  }
}

class _RankingTile extends StatelessWidget {
  const _RankingTile({
    required this.index,
    required this.summary,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final PlayerPlaytimeSummary summary;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).dividerColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
          color: selected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Text(
                '#$index',
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Expanded(
              child: Text(
                summary.nickname,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            _MetricChip(
              label: 'Dia',
              value: _formatSeconds(summary.dailySeconds),
            ),
            const SizedBox(width: 6),
            _MetricChip(
              label: 'Semana',
              value: _formatSeconds(summary.weeklySeconds),
            ),
            const SizedBox(width: 6),
            _MetricChip(
              label: 'Total',
              value: _formatSeconds(summary.totalSeconds),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session});

  final PlayerSessionEntry session;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd/MM HH:mm');
    final started = formatter.format(session.startAt.toLocal());
    final ended = session.endAt == null
        ? '--'
        : formatter.format(session.endAt!.toLocal());
    final reason = session.closeReason ?? (session.isOpen ? 'open' : '-');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 6,
        children: [
          Text('Início: $started'),
          Text('Fim: $ended'),
          Text('Duração: ${_formatDuration(session.duration)}'),
          Text('Motivo: $reason'),
          if (session.isIncomplete)
            Text(
              'Sessão incompleta',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

String _formatSeconds(int seconds) {
  if (seconds <= 0) {
    return '0m';
  }
  return _formatDuration(Duration(seconds: seconds));
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;
  if (hours > 0) {
    return '${hours}h ${minutes}m';
  }
  return '${minutes}m';
}
