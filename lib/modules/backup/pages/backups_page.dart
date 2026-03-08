import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../components/badges/app_badge.dart';
import '../../../components/buttons/app_button.dart';
import '../../../components/inputs/app_text_input.dart';
import '../../../components/modal/app_modal.dart';
import '../../../components/shared/app_variant.dart';
import '../../../config/routes/routes_config.dart';
import '../../../config/theme/app_styles.dart';
import '../../../config/theme/app_theme_extension.dart';
import '../../../layout/default_layout.dart';
import '../../../models/server_lifecycle_state.dart';
import '../models/backup_capacity_status.dart';
import '../models/backup_entry.dart';
import '../providers/backup_config_provider.dart';
import '../providers/backups_provider.dart';
import '../../server/providers/server_runtime_provider.dart';
import '../subcomponents/selective_backup_modal.dart';

class BackupsPage extends ConsumerStatefulWidget {
  const BackupsPage({super.key});

  @override
  ConsumerState<BackupsPage> createState() => _BackupsPageState();
}

class _BackupsPageState extends ConsumerState<BackupsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(backupsProvider);
    final notifier = ref.read(backupsProvider.notifier);
    final backupConfig = ref.watch(backupConfigProvider);
    final runtime = ref.watch(serverRuntimeProvider);
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final capacity = state.capacity;

    final filtered = state.entries.where((entry) {
      final query = _query.trim().toLowerCase();
      if (query.isEmpty) return true;
      return entry.name.toLowerCase().contains(query);
    }).toList();

    final totalSize = filtered.fold<int>(
      0,
      (sum, item) => sum + item.sizeBytes,
    );

    return DefaultLayout(
      title: 'MineControl',
      currentRoute: AppRoutes.backups,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      title: 'Total de backups',
                      value: '${filtered.length}',
                      icon: Icons.inventory_2_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      title: 'Peso total',
                      value: _formatSize(totalSize),
                      icon: Icons.sd_storage_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      title: 'Limite (retenção)',
                      value: capacity == null || !capacity.hasLimit
                          ? 'Ilimitado'
                          : _formatSize(capacity.limitBytes),
                      icon: Icons.rule_folder_rounded,
                    ),
                  ),
                ],
              ),
              if (capacity != null && capacity.hasLimit) ...[
                const SizedBox(height: 10),
                _CapacityBadge(capacity: capacity),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: AppTextInput(
                      controller: _searchController,
                      hint: 'Pesquisar backup por nome',
                      prefixIcon: const Icon(Icons.search_rounded),
                      onChanged: (value) => setState(() => _query = value),
                    ),
                  ),
                  const SizedBox(width: 10),
                  AppButton(
                    label: 'Atualizar',
                    icon: Icons.refresh_rounded,
                    variant: AppVariant.info,
                    onPressed: notifier.load,
                  ),
                  const SizedBox(width: 10),
                  AppButton(
                    label: 'Backup mundo',
                    icon: Icons.public_rounded,
                    variant: AppVariant.secondary,
                    isDisabled: state.creating,
                    isLoading: state.creating,
                    onPressed: notifier.createManualWorldBackup,
                  ),
                  const SizedBox(width: 10),
                  AppButton(
                    label: 'Backup seletivo',
                    icon: Icons.library_add_check_rounded,
                    variant: AppVariant.primary,
                    isDisabled: state.creating,
                    onPressed: () async {
                      await showDialog<bool>(
                        context: context,
                        builder: (_) => SelectiveBackupModal(
                          onConfirm: notifier.createManualSelectiveBackup,
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (state.loading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (filtered.isEmpty)
                Expanded(
                  child: _BackupsEmptyState(
                    backupsEnabled: backupConfig.backupsEnabled,
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final entry = filtered[index];
                      return _BackupCard(
                        entry: entry,
                        restoreEnabled:
                            runtime.lifecycle == ServerLifecycleState.offline &&
                            runtime.activePlayers == 0 &&
                            !state.creating,
                        onRestoreWorld: () =>
                            _runRestoreFlow(ref, entry, fullRestore: false),
                        onRestoreFull: () =>
                            _runRestoreFlow(ref, entry, fullRestore: true),
                        onDelete: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (_) => AppModal(
                              icon: Icons.delete_rounded,
                              title: 'Remover backup',
                              body: Text(
                                'Deseja remover o backup ${entry.name}?',
                              ),
                              actions: [
                                AppButton(
                                  label: 'Cancelar',
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                  variant: AppVariant.danger,
                                  type: AppButtonType.textButton,
                                ),
                                AppButton(
                                  label: 'Confirmar',
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
                                  variant: AppVariant.success,
                                  icon: Icons.check_rounded,
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true && mounted) {
                            await notifier.deleteBackup(entry.path);
                          }
                        },
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

  String _formatSize(int sizeBytes) {
    final megaBytes = sizeBytes / (1024 * 1024);
    if (megaBytes > 24) {
      final gigaBytes = sizeBytes / (1024 * 1024 * 1024);
      return '${gigaBytes.toStringAsFixed(2)} GB';
    }
    return '${megaBytes.toStringAsFixed(2)} MB';
  }

  Future<void> _runRestoreFlow(
    WidgetRef ref,
    BackupEntry entry, {
    required bool fullRestore,
  }) async {
    final label = fullRestore ? 'completa' : 'de mundo';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AppModal(
        icon: Icons.restore_page_rounded,
        title: 'Confirmar restauração $label',
        body: Text(
          fullRestore
              ? 'A restauração completa sobrescreve toda a raiz do servidor. Um backup de segurança será criado antes da operação. Deseja continuar?'
              : 'A restauração de mundo sobrescreve apenas a pasta do mundo atual. Um backup de segurança será criado antes da operação. Deseja continuar?',
        ),
        actions: [
          AppButton(
            label: 'Cancelar',
            onPressed: () => Navigator.of(context).pop(false),
            type: AppButtonType.textButton,
            variant: AppVariant.danger,
          ),
          AppButton(
            label: 'Confirmar restauração',
            onPressed: () => Navigator.of(context).pop(true),
            variant: AppVariant.warning,
            icon: Icons.check_rounded,
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    try {
      if (fullRestore) {
        await ref.read(backupsProvider.notifier).restoreFullBackup(entry.path);
      } else {
        await ref.read(backupsProvider.notifier).restoreWorldBackup(entry.path);
      }
    } catch (error) {
      if (!mounted) return;
      final msg = error.toString().replaceFirst('Bad state: ', '');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return;
    }

    if (!mounted) return;
    final startNow = await showDialog<bool>(
      context: context,
      builder: (_) => AppModal(
        icon: Icons.play_arrow_rounded,
        title: 'Restauração concluída',
        body: const Text(
          'Deseja iniciar o servidor agora ou manter desligado?',
        ),
        actions: [
          AppButton(
            label: 'Manter desligado',
            onPressed: () => Navigator.of(context).pop(false),
            type: AppButtonType.textButton,
            variant: AppVariant.info,
          ),
          AppButton(
            label: 'Iniciar servidor',
            onPressed: () => Navigator.of(context).pop(true),
            variant: AppVariant.success,
            icon: Icons.play_arrow_rounded,
          ),
        ],
      ),
    );

    if (startNow == true) {
      await ref.read(serverRuntimeProvider.notifier).startServer();
    }
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ext.cardBackground,
        borderRadius: AppStyles.radiusMd,
        border: Border.all(color: ext.cardBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BackupsEmptyState extends StatelessWidget {
  const _BackupsEmptyState({required this.backupsEnabled});

  final bool backupsEnabled;

  @override
  Widget build(BuildContext context) {
    final text = backupsEnabled
        ? 'Você não tem nenhum backup no momento.'
        : 'Você não tem nenhum backup no momento ou os backups estão desativados.';

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inbox_rounded,
            size: 44,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ],
      ),
    );
  }
}

class _BackupCard extends StatelessWidget {
  const _BackupCard({
    required this.entry,
    required this.restoreEnabled,
    required this.onRestoreWorld,
    required this.onRestoreFull,
    required this.onDelete,
  });

  final BackupEntry entry;
  final bool restoreEnabled;
  final VoidCallback onRestoreWorld;
  final VoidCallback onRestoreFull;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final dateLabel = DateFormat('dd/MM/yyyy HH:mm').format(entry.modifiedAt);
    final sizeLabel = _formatSize(entry.sizeBytes);
    final kindLabel = switch (entry.origin) {
      BackupOriginKind.manual => 'Manual',
      BackupOriginKind.schedule => 'Agendamento',
      BackupOriginKind.chunk => 'Chunk',
      BackupOriginKind.unknown => 'Outro',
    };
    final contentLabel = switch (entry.contentKind) {
      BackupContentKind.full => 'full',
      BackupContentKind.world => 'world',
      BackupContentKind.selective => 'selective',
      BackupContentKind.app => 'app',
      BackupContentKind.unknown => 'unknown',
    };

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
            Icons.folder_zip_rounded,
            color: Theme.of(context).colorScheme.secondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '$kindLabel/$contentLabel • $dateLabel • $sizeLabel',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: ext.mutedText),
                ),
                if (entry.description != null &&
                    entry.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Itens raiz: ${entry.description!}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: ext.mutedText),
                  ),
                ],
              ],
            ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              AppButton(
                label: 'Restaurar mundo',
                icon: Icons.public_rounded,
                variant: AppVariant.info,
                transparent: true,
                isDisabled: !restoreEnabled,
                onPressed: restoreEnabled ? onRestoreWorld : null,
              ),
              AppButton(
                label: 'Restaurar completo',
                icon: Icons.restart_alt_rounded,
                variant: AppVariant.warning,
                transparent: true,
                isDisabled: !restoreEnabled,
                onPressed: restoreEnabled ? onRestoreFull : null,
              ),
              AppButton(
                label: 'Apagar',
                icon: Icons.delete_outline_rounded,
                variant: AppVariant.danger,
                transparent: true,
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatSize(int sizeBytes) {
    final megaBytes = sizeBytes / (1024 * 1024);
    if (megaBytes > 24) {
      final gigaBytes = sizeBytes / (1024 * 1024 * 1024);
      return '${gigaBytes.toStringAsFixed(2)} GB';
    }
    return '${megaBytes.toStringAsFixed(2)} MB';
  }
}

class _CapacityBadge extends StatelessWidget {
  const _CapacityBadge({required this.capacity});

  final BackupCapacityStatus capacity;

  @override
  Widget build(BuildContext context) {
    final level = capacity.level;
    final variant = switch (level) {
      BackupCapacityLevel.normal => AppVariant.success,
      BackupCapacityLevel.warning => AppVariant.warning,
      BackupCapacityLevel.reached => AppVariant.warning,
      BackupCapacityLevel.exceeded => AppVariant.danger,
    };
    final title = switch (level) {
      BackupCapacityLevel.normal => 'Capacidade normal',
      BackupCapacityLevel.warning => 'Capacidade próxima do limite',
      BackupCapacityLevel.reached => 'Limite de capacidade atingido',
      BackupCapacityLevel.exceeded => 'Limite de capacidade excedido',
    };

    return AppBadge(
      icon: Icons.storage_rounded,
      variant: variant,
      title:
          '$title (${capacity.usedPercent.toStringAsFixed(1)}% • ${_formatSizeStatic(capacity.usedBytes)} de ${_formatSizeStatic(capacity.limitBytes)})',
    );
  }
}

String _formatSizeStatic(int sizeBytes) {
  final megaBytes = sizeBytes / (1024 * 1024);
  if (megaBytes > 24) {
    final gigaBytes = sizeBytes / (1024 * 1024 * 1024);
    return '${gigaBytes.toStringAsFixed(2)} GB';
  }
  return '${megaBytes.toStringAsFixed(2)} MB';
}
