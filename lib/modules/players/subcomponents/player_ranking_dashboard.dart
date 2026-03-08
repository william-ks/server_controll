import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../components/buttons/app_button.dart';
import '../../../components/shared/app_variant.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_theme_extension.dart';
import '../models/player_playtime_summary.dart';
import '../models/player_ranking_period.dart';
import '../providers/player_playtime_provider.dart';

class PlayerRankingDashboard extends StatelessWidget {
  const PlayerRankingDashboard({
    super.key,
    required this.state,
    required this.onRefresh,
    required this.onToggleShowAll,
    required this.onPeriodChanged,
  });

  final PlayerPlaytimeState state;
  final Future<void> Function() onRefresh;
  final VoidCallback onToggleShowAll;
  final ValueChanged<PlayerRankingPeriod> onPeriodChanged;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final ranking = state.ranking.where((item) => item.totalSeconds > 0).toList();
    final visibleRanking = state.showFullRanking ? ranking : ranking.take(3).toList();
    final chartEntries = _buildChartEntries(ranking, state.selectedPeriod);
    final totalPeriodSeconds = chartEntries.fold<int>(
      0,
      (sum, item) => sum + item.seconds,
    );
    final leader = ranking.isEmpty ? null : ranking.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dashboard de ranking',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Top players por tempo de jogatina e distribuição por período.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: ext.mutedText,
                    ),
                  ),
                ],
              ),
            ),
            AppButton(
              label: 'Atualizar',
              icon: Icons.refresh_rounded,
              variant: AppVariant.info,
              transparent: true,
              isDisabled: state.syncing,
              isLoading: state.syncing,
              onPressed: onRefresh,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _SummaryCard(
              title: 'Leader',
              value: leader?.nickname ?? '--',
              subtitle: leader == null
                  ? 'Sem horas registradas'
                  : _formatSeconds(leader.totalSeconds),
            ),
            _SummaryCard(
              title: 'Players ranqueados',
              value: '${ranking.length}',
              subtitle: 'Com horas registradas',
            ),
            _SummaryCard(
              title: 'Período atual',
              value: state.selectedPeriod.label,
              subtitle: _formatSeconds(totalPeriodSeconds),
            ),
          ],
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 980;
            if (stacked) {
              return Column(
                children: [
                  _rankingCard(context, visibleRanking, ranking),
                  const SizedBox(height: 16),
                  _chartCard(context, chartEntries, totalPeriodSeconds),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 11,
                  child: _rankingCard(context, visibleRanking, ranking),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 13,
                  child: _chartCard(context, chartEntries, totalPeriodSeconds),
                ),
              ],
            );
          },
        ),
        if (state.error != null) ...[
          const SizedBox(height: 12),
          Text(
            state.error!.replaceFirst('Bad state: ', ''),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }

  Widget _rankingCard(
    BuildContext context,
    List<PlayerPlaytimeSummary> visibleRanking,
    List<PlayerPlaytimeSummary> fullRanking,
  ) {
    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  state.showFullRanking ? 'Ranking completo' : 'Top 3 players',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (fullRanking.length > 3)
                AppButton(
                  label: state.showFullRanking ? 'Ver top 3' : 'Ver todos',
                  type: AppButtonType.textButton,
                  variant: AppVariant.primary,
                  onPressed: onToggleShowAll,
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (fullRanking.isEmpty)
            Text(
              'Sem players ativos com tempo de jogo registrado.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          else
            for (var i = 0; i < visibleRanking.length; i++)
              _RankingRow(
                position: i + 1,
                summary: visibleRanking[i],
              ),
        ],
      ),
    );
  }

  Widget _chartCard(
    BuildContext context,
    List<_ChartEntry> chartEntries,
    int totalPeriodSeconds,
  ) {
    final chartColors = _chartPalette;
    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Distribuição do tempo de jogatina',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final period in PlayerRankingPeriod.values)
                ChoiceChip(
                  label: Text(period.label),
                  selected: period == state.selectedPeriod,
                  onSelected: (_) => onPeriodChanged(period),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (chartEntries.isEmpty)
            Text(
              'Sem dados para o período ${state.selectedPeriod.label.toLowerCase()}.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          else ...[
            SizedBox(
              height: 280,
              child: PieChart(
                PieChartData(
                  centerSpaceRadius: 56,
                  sectionsSpace: 3,
                  sections: [
                    for (var i = 0; i < chartEntries.length; i++)
                      PieChartSectionData(
                        value: chartEntries[i].seconds.toDouble(),
                        color: chartColors[i % chartColors.length],
                        radius: 88,
                        title:
                            '${((chartEntries[i].seconds / totalPeriodSeconds) * 100).toStringAsFixed(0)}%',
                        titleStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < chartEntries.length; i++)
              _LegendRow(
                color: chartColors[i % chartColors.length],
                label: chartEntries[i].nickname,
                value: _formatSeconds(chartEntries[i].seconds),
                percentage:
                    ((chartEntries[i].seconds / totalPeriodSeconds) * 100),
              ),
          ],
        ],
      ),
    );
  }

  List<_ChartEntry> _buildChartEntries(
    List<PlayerPlaytimeSummary> ranking,
    PlayerRankingPeriod period,
  ) {
    final entries = ranking
        .map(
          (item) => _ChartEntry(
            nickname: item.nickname,
            seconds: switch (period) {
              PlayerRankingPeriod.daily => item.dailySeconds,
              PlayerRankingPeriod.weekly => item.weeklySeconds,
              PlayerRankingPeriod.monthly => item.monthlySeconds,
            },
          ),
        )
        .where((item) => item.seconds > 0)
        .toList()
      ..sort((a, b) => b.seconds.compareTo(a.seconds));
    return entries.take(8).toList();
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.22,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: child,
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.18,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _RankingRow extends StatelessWidget {
  const _RankingRow({
    required this.position,
    required this.summary,
  });

  final int position;
  final PlayerPlaytimeSummary summary;

  @override
  Widget build(BuildContext context) {
    final accent = switch (position) {
      1 => AppColors.warning,
      2 => AppColors.info,
      3 => AppColors.success,
      _ => Theme.of(context).colorScheme.primary,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.34)),
        color: accent.withValues(alpha: 0.08),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.16),
            ),
            child: Text(
              '$position',
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              summary.nickname,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _MetricPill(label: 'Dia', value: _formatSeconds(summary.dailySeconds)),
          const SizedBox(width: 6),
          _MetricPill(
            label: 'Semana',
            value: _formatSeconds(summary.weeklySeconds),
          ),
          const SizedBox(width: 6),
          _MetricPill(
            label: 'Mês',
            value: _formatSeconds(summary.monthlySeconds),
          ),
          const SizedBox(width: 6),
          _MetricPill(
            label: 'Total',
            value: _formatSeconds(summary.totalSeconds),
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label, required this.value});

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

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.label,
    required this.value,
    required this.percentage,
  });

  final Color color;
  final String label;
  final String value;
  final double percentage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '${percentage.toStringAsFixed(1)}% • $value',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ChartEntry {
  const _ChartEntry({
    required this.nickname,
    required this.seconds,
  });

  final String nickname;
  final int seconds;
}

const List<Color> _chartPalette = [
  AppColors.primary,
  AppColors.success,
  AppColors.warning,
  AppColors.info,
  Color(0xFFE07A5F),
  Color(0xFF5F0F40),
  Color(0xFF2A9D8F),
  Color(0xFF8D99AE),
];

String _formatSeconds(int seconds) {
  if (seconds <= 0) {
    return '0m';
  }
  final duration = Duration(seconds: seconds);
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours > 0) {
    return '${hours}h ${minutes}m';
  }
  return '${duration.inMinutes}m';
}
