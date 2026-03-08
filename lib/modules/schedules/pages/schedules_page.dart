import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../components/badges/app_badge.dart';
import '../../../components/buttons/app_button.dart';
import '../../../components/inputs/app_text_input.dart';
import '../../../components/shared/app_variant.dart';
import '../../../config/routes/routes_config.dart';
import '../../../config/theme/app_styles.dart';
import '../../../config/theme/app_theme_extension.dart';
import '../../../layout/default_layout.dart';
import '../../backup/providers/auto_backup_status_provider.dart';
import '../models/schedule_action.dart';
import '../models/schedule_backup_kind.dart';
import '../models/schedule_item.dart';
import '../providers/schedules_provider.dart';
import '../subcomponents/add_schedule_modal.dart';

class SchedulesPage extends ConsumerStatefulWidget {
  const SchedulesPage({super.key});

  @override
  ConsumerState<SchedulesPage> createState() => _SchedulesPageState();
}

class _SchedulesPageState extends ConsumerState<SchedulesPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(schedulesProvider);
    final autoBackupStatus = ref.watch(autoBackupStatusProvider);
    final notifier = ref.read(schedulesProvider.notifier);
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    final filtered = state.items.where((item) {
      final q = _query.trim().toLowerCase();
      if (q.isEmpty) return true;
      return item.title.toLowerCase().contains(q) ||
          item.cronExpression.toLowerCase().contains(q) ||
          item.action.label.toLowerCase().contains(q);
    }).toList();

    return DefaultLayout(
      title: 'MineControl',
      currentRoute: AppRoutes.schedules,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: ext.cardBackground,
            borderRadius: AppStyles.radiusLg,
            border: Border.all(color: ext.cardBorder),
            boxShadow: AppStyles.softShadow(opacity: 0.12),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: AppTextInput(
                      controller: _searchController,
                      hint: 'Pesquisar agendamento',
                      prefixIcon: const Icon(Icons.search_rounded),
                      onChanged: (value) => setState(() => _query = value),
                    ),
                  ),
                  const SizedBox(width: 10),
                  AppButton(
                    label: 'Adicionar',
                    icon: Icons.add_rounded,
                    onPressed: () {
                      showDialog<void>(
                        context: context,
                        builder: (_) => AddScheduleModal(
                          onCreate:
                              ({
                                required String title,
                                required String cronExpression,
                                required ScheduleAction action,
                                required bool withBackup,
                                required ScheduleBackupKind backupKind,
                                required List<String> selectiveRootEntries,
                              }) => notifier.create(
                                title: title,
                                cronExpression: cronExpression,
                                action: action,
                                withBackup: withBackup,
                                backupKind: backupKind,
                                selectiveRootEntries: selectiveRootEntries,
                              ),
                        ),
                      );
                    },
                    variant: AppVariant.primary,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (autoBackupStatus.running)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: AppBadge(
                    icon: Icons.backup_rounded,
                    variant: AppVariant.info,
                    title: 'Backup automático em execução.',
                  ),
                ),
              if (autoBackupStatus.lastError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppBadge(
                    icon: Icons.error_outline_rounded,
                    variant: AppVariant.danger,
                    title: 'Falha em backup automático',
                    description: autoBackupStatus.lastError!,
                  ),
                ),
              if (state.loading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (filtered.isEmpty)
                Expanded(
                  child: Center(
                    child: Text(
                      'Nenhum agendamento encontrado.',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      return _ScheduleCard(
                        item: item,
                        onToggleActive: (value) =>
                            notifier.setActive(item: item, active: value),
                        onDelete: () => notifier.delete(item.id!),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.item,
    required this.onToggleActive,
    required this.onDelete,
  });

  final ScheduleItem item;
  final ValueChanged<bool> onToggleActive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final lastRun = item.lastExecutedAt == null
        ? 'Nunca executado'
        : DateFormat('dd/MM HH:mm').format(item.lastExecutedAt!);
    final backupLabel = item.withBackup ? item.backupKind.label : 'Não';
    final selectiveSuffix =
        item.withBackup &&
            item.backupKind == ScheduleBackupKind.selective &&
            item.selectiveRootEntries.isNotEmpty
        ? ' (${item.selectiveRootEntries.join(', ')})'
        : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ext.cardBackground,
        borderRadius: AppStyles.radiusMd,
        border: Border.all(color: ext.cardBorder),
      ),
      child: Row(
        children: [
          Icon(
            item.isActive
                ? Icons.schedule_send_rounded
                : Icons.schedule_rounded,
            color: item.isActive
                ? Theme.of(context).colorScheme.primary
                : ext.mutedText,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title.trim().isEmpty
                      ? 'Agendamento sem título'
                      : item.title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.cronExpression} • ${item.action.label} • Backup: $backupLabel$selectiveSuffix • $lastRun',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: ext.mutedText),
                ),
              ],
            ),
          ),
          Switch.adaptive(value: item.isActive, onChanged: onToggleActive),
          AppButton(
            label: 'Excluir',
            variant: AppVariant.danger,
            type: AppButtonType.textButton,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
