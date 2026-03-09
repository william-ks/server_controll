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
    final ranking = [...state.ranking];
    final visibleRanking = state.showFullRanking
        ? ranking
        : ranking.take(3).toList();
    final chartEntries = _buildChartEntries(ranking, state.selectedPeriod);
    final currentPeriodTotal = ranking.fold<int>(
      0,
      (sum, item) => sum + _periodSeconds(item, state.selectedPeriod),
    );
    final leader = ranking.isEmpty ? null : ranking.first;
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 12.0;
            const minWidth = 220.0;
            final columns = _resolveColumns(
              maxWidth: constraints.maxWidth,
              minWidth: minWidth,
              spacing: spacing,
            );
            final cardWidth =
                (constraints.maxWidth - (spacing * (columns - 1))) / columns;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: _OverviewMetricCard(
                    title: 'LÍDER',
                    value: leader?.nickname ?? '--',
                    subtitle: leader == null
                        ? 'Sem horas registradas'
                        : _formatSeconds(leader.totalSeconds),
                    icon: Icons.workspace_premium_rounded,
                    valueColor: AppColors.warning,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _OverviewMetricCard(
                    title: 'PLAYERS RANQUEADOS',
                    value: '${ranking.length}',
                    subtitle: ranking.isEmpty
                        ? 'Nenhum player listado'
                        : 'Inclui players zerados',
                    icon: Icons.groups_2_rounded,
                    valueColor: AppColors.info,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _OverviewMetricCard(
                    title: 'PERÍODO ATUAL',
                    value: state.selectedPeriod.label.toUpperCase(),
                    subtitle: _formatSeconds(currentPeriodTotal),
                    icon: Icons.timer_outlined,
                    valueColor: AppColors.success,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 980;
            if (stacked) {
              return Column(
                children: [
                  _rankingCard(context, visibleRanking, ranking, ext),
                  const SizedBox(height: 16),
                  _chartCard(context, chartEntries, ext),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 11,
                  child: _rankingCard(context, visibleRanking, ranking, ext),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 13,
                  child: _chartCard(context, chartEntries, ext),
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
    AppThemeExtension ext,
  ) {
    return _PanelCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.leaderboard_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      state.showFullRanking
                          ? 'Ranking completo'
                          : 'Top 3 players',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
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
              if (fullRanking.length > 3)
                AppButton(
                  label: state.showFullRanking ? 'Ver top 3' : 'Ver todos',
                  type: AppButtonType.textButton,
                  variant: AppVariant.primary,
                  onPressed: onToggleShowAll,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Lista geral dos players da whitelist com tempo acumulado.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: ext.mutedText),
          ),
          const SizedBox(height: 14),
          if (fullRanking.isEmpty)
            Text(
              'Nenhum player disponível para o ranking.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          else
            for (var i = 0; i < visibleRanking.length; i++)
              _RankingRow(position: i + 1, summary: visibleRanking[i]),
        ],
      ),
    );
  }

  Widget _chartCard(
    BuildContext context,
    List<_ChartEntry> chartEntries,
    AppThemeExtension ext,
  ) {
    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.bar_chart_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Distribuição por tempo',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Comparativo de jogatina por período entre os players mais relevantes.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: ext.mutedText),
          ),
          const SizedBox(height: 12),
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
          const SizedBox(height: 16),
          if (chartEntries.isEmpty)
            Container(
              height: 300,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.14),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.hourglass_empty_rounded,
                    size: 34,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Sem tempo registrado no período ${state.selectedPeriod.label.toLowerCase()}.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            SizedBox(
              height: 300,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _resolveMaxY(chartEntries),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Theme.of(
                        context,
                      ).dividerColor.withValues(alpha: 0.5),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        reservedSize: 48,
                        showTitles: true,
                        getTitlesWidget: (value, meta) => Text(
                          _formatAxis(value.toInt()),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= chartEntries.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _shorten(chartEntries[index].nickname),
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < chartEntries.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: chartEntries[i].seconds.toDouble(),
                            width: 24,
                            borderRadius: BorderRadius.circular(8),
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.info],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            for (final entry in chartEntries)
              _LegendRow(
                color: AppColors.primary,
                label: entry.nickname,
                value: _formatSeconds(entry.seconds),
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
    final entries =
        ranking
            .map(
              (item) => _ChartEntry(
                nickname: item.nickname,
                seconds: _periodSeconds(item, period),
              ),
            )
            .toList()
          ..sort((a, b) => b.seconds.compareTo(a.seconds));
    return entries.take(8).toList();
  }

  int _periodSeconds(PlayerPlaytimeSummary item, PlayerRankingPeriod period) {
    return switch (period) {
      PlayerRankingPeriod.daily => item.dailySeconds,
      PlayerRankingPeriod.weekly => item.weeklySeconds,
      PlayerRankingPeriod.monthly => item.monthlySeconds,
    };
  }

  double _resolveMaxY(List<_ChartEntry> entries) {
    final max = entries.fold<int>(
      0,
      (current, item) => item.seconds > current ? item.seconds : current,
    );
    if (max <= 0) return 1;
    return (max * 1.2).ceilToDouble();
  }

  int _resolveColumns({
    required double maxWidth,
    required double minWidth,
    required double spacing,
  }) {
    for (var columns = 3; columns >= 1; columns--) {
      final width = (maxWidth - (spacing * (columns - 1))) / columns;
      if (width >= minWidth) {
        return columns;
      }
    }
    return 1;
  }
}

class _OverviewMetricCard extends StatelessWidget {
  const _OverviewMetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.valueColor,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: ext.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ext.cardBorder.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: valueColor),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ext.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ext.cardBorder.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _RankingRow extends StatelessWidget {
  const _RankingRow({required this.position, required this.summary});

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
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.26)),
        color: accent.withValues(alpha: 0.07),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.16),
                ),
                child: Text(
                  '$position',
                  style: TextStyle(color: accent, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  summary.nickname,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                _formatSeconds(summary.totalSeconds),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetricPill(
                label: 'Dia',
                value: _formatSeconds(summary.dailySeconds),
              ),
              _MetricPill(
                label: 'Semana',
                value: _formatSeconds(summary.weeklySeconds),
              ),
              _MetricPill(
                label: 'Mês',
                value: _formatSeconds(summary.monthlySeconds),
              ),
              _MetricPill(
                label: 'Total',
                value: _formatSeconds(summary.totalSeconds),
              ),
            ],
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
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: ext.cardBackground,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ext.cardBorder.withValues(alpha: 0.5)),
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
  });

  final Color color;
  final String label;
  final String value;

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
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Text(value, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _ChartEntry {
  const _ChartEntry({required this.nickname, required this.seconds});

  final String nickname;
  final int seconds;
}

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

String _formatAxis(int seconds) {
  if (seconds <= 0) return '0m';
  final minutes = Duration(seconds: seconds).inMinutes;
  if (minutes >= 60) {
    return '${(minutes / 60).floor()}h';
  }
  return '${minutes}m';
}

String _shorten(String nickname) {
  if (nickname.length <= 10) return nickname;
  return '${nickname.substring(0, 10)}...';
}
