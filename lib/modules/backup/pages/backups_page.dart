import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../components/buttons/app_button.dart';
import '../../../components/inputs/app_text_input.dart';
import '../../../components/modal/app_modal.dart';
import '../../../components/shared/app_variant.dart';
import '../../../config/routes/routes_config.dart';
import '../../../config/theme/app_styles.dart';
import '../../../config/theme/app_theme_extension.dart';
import '../../../layout/default_layout.dart';
import '../models/backup_entry.dart';
import '../providers/backup_config_provider.dart';
import '../providers/backups_provider.dart';

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
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

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
                ],
              ),
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
  const _BackupCard({required this.entry, required this.onDelete});

  final BackupEntry entry;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final dateLabel = DateFormat('dd/MM/yyyy HH:mm').format(entry.modifiedAt);
    final sizeLabel = _formatSize(entry.sizeBytes);
    final kindLabel = switch (entry.kind) {
      BackupKind.manual => 'Manual',
      BackupKind.schedule => 'Agendamento',
      BackupKind.chunk => 'Chunk',
      BackupKind.unknown => 'Outro',
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
                  '$kindLabel • $dateLabel • $sizeLabel',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: ext.mutedText),
                ),
              ],
            ),
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
