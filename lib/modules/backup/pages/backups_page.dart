import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import '../../../components/badges/app_badge.dart';
import '../../../components/buttons/app_button.dart';
import '../../../components/inputs/app_switch_card.dart';
import '../../../components/inputs/app_text_input.dart';
import '../../../components/modal/app_modal.dart';
import '../../../components/shared/app_variant.dart';
import '../../../config/routes/routes_config.dart';
import '../../../config/theme/app_styles.dart';
import '../../../config/theme/app_theme_extension.dart';
import '../../../layout/default_layout.dart';
import '../../../models/server_lifecycle_state.dart';
import '../../schedules/services/cron_matcher.dart';
import '../models/app_backup_settings.dart';
import '../models/backup_capacity_status.dart';
import '../models/backup_entry.dart';
import '../models/app_backup_entry.dart';
import '../providers/app_backups_provider.dart';
import '../providers/app_backup_settings_provider.dart';
import '../providers/backup_config_provider.dart';
import '../providers/backups_provider.dart';
import '../../server/providers/server_runtime_provider.dart';
import '../subcomponents/manual_server_backup_wizard_modal.dart';

class BackupsPage extends ConsumerStatefulWidget {
  const BackupsPage({super.key});

  @override
  ConsumerState<BackupsPage> createState() => _BackupsPageState();
}

class _BackupsPageState extends ConsumerState<BackupsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  _BackupsTab _tab = _BackupsTab.server;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(backupsProvider);
    final appBackupsState = ref.watch(appBackupsProvider);
    final appBackupSettings = ref.watch(appBackupSettingsProvider);
    final notifier = ref.read(backupsProvider.notifier);
    final appBackupsNotifier = ref.read(appBackupsProvider.notifier);
    final appBackupSettingsNotifier = ref.read(
      appBackupSettingsProvider.notifier,
    );
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
                  _tabChip('Backup servidor', _BackupsTab.server),
                  const SizedBox(width: 8),
                  _tabChip('Backup app', _BackupsTab.app),
                ],
              ),
              const SizedBox(height: 12),
              if (_tab == _BackupsTab.server) ...[
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
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 420,
                      child: AppTextInput(
                        controller: _searchController,
                        hint: 'Pesquisar backup por nome',
                        prefixIcon: const Icon(Icons.search_rounded),
                        onChanged: (value) => setState(() => _query = value),
                      ),
                    ),
                    AppButton(
                      label: 'Atualizar',
                      icon: Icons.refresh_rounded,
                      variant: AppVariant.info,
                      onPressed: notifier.load,
                    ),
                    AppButton(
                      label: 'Novo backup',
                      icon: Icons.backup_rounded,
                      variant: AppVariant.primary,
                      isDisabled: state.creating,
                      onPressed: () => _openManualBackupWizard(notifier),
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
                              runtime.lifecycle ==
                                  ServerLifecycleState.offline &&
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
              ] else ...[
                _buildAppBackupSection(
                  appBackupsState: appBackupsState,
                  appBackupsNotifier: appBackupsNotifier,
                  appBackupSettings: appBackupSettings,
                  appBackupSettingsNotifier: appBackupSettingsNotifier,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openManualBackupWizard(BackupsNotifier notifier) async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => ManualServerBackupWizardModal(
        onConfirm: ({required kind, required selectiveRootEntries}) async {
          switch (kind) {
            case BackupContentKind.full:
              await notifier.createManualBackup();
            case BackupContentKind.world:
              await notifier.createManualWorldBackup();
            case BackupContentKind.selective:
              await notifier.createManualSelectiveBackup(selectiveRootEntries);
            case BackupContentKind.app:
            case BackupContentKind.unknown:
              throw StateError('Tipo de backup manual não suportado na tela.');
          }
        },
      ),
    );
    if (created != true || !mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Backup manual concluído com sucesso.')),
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

  Widget _tabChip(String label, _BackupsTab tab) {
    final active = _tab == tab;
    return InkWell(
      onTap: () => setState(() => _tab = tab),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor,
          ),
          color: active
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
              : Colors.transparent,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
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

  Widget _buildAppBackupSection({
    required AppBackupsState appBackupsState,
    required AppBackupsNotifier appBackupsNotifier,
    required AppBackupSettings appBackupSettings,
    required AppBackupSettingsNotifier appBackupSettingsNotifier,
  }) {
    final appBackupPath = appBackupSettings.backupPath.trim();
    final pathLabel = appBackupPath.isEmpty
        ? 'Padrão do aplicativo (app_support/app_backups)'
        : appBackupPath;
    final cron = appBackupSettings.cronExpression.trim().isEmpty
        ? '0 */6 * * *'
        : appBackupSettings.cronExpression.trim();
    final scheduleLabel = appBackupSettings.autoEnabled
        ? 'Ativo ($cron)'
        : 'Desativado';

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppBadge(
            title: 'Pasta: $pathLabel',
            description: 'Agenda automática: $scheduleLabel',
            icon: Icons.settings_suggest_rounded,
            variant: AppVariant.info,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              AppButton(
                label: 'Criar backup do app',
                icon: Icons.backup_rounded,
                variant: AppVariant.success,
                isLoading: appBackupsState.running,
                isDisabled: appBackupsState.running,
                onPressed: () => _runAppAction(
                  action: appBackupsNotifier.createManualBackup,
                  successMessage: 'Backup do app criado com sucesso.',
                ),
              ),
              const SizedBox(width: 10),
              AppButton(
                label: 'Importar',
                icon: Icons.file_upload_rounded,
                variant: AppVariant.info,
                transparent: true,
                onPressed: () async {
                  final picked = await FilePicker.platform.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['zip'],
                  );
                  final path = picked?.files.single.path;
                  if (path == null) return;
                  await _runAppAction(
                    action: () => appBackupsNotifier.importBackup(path),
                    successMessage: 'Backup importado com sucesso.',
                  );
                },
              ),
              const SizedBox(width: 10),
              AppButton(
                label: 'Configuração',
                icon: Icons.settings_rounded,
                variant: AppVariant.secondary,
                transparent: true,
                onPressed: () async {
                  final saved = await _openAppBackupSettingsModal(
                    settings: appBackupSettings,
                    notifier: appBackupSettingsNotifier,
                  );
                  if (saved) {
                    await appBackupsNotifier.load();
                  }
                },
              ),
              const SizedBox(width: 10),
              AppButton(
                label: 'Atualizar',
                icon: Icons.refresh_rounded,
                variant: AppVariant.secondary,
                transparent: true,
                onPressed: appBackupsNotifier.load,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (appBackupsState.error != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                appBackupsState.error!.replaceFirst('Bad state: ', ''),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 8),
          if (appBackupsState.loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (appBackupsState.entries.isEmpty)
            const Expanded(
              child: Center(child: Text('Nenhum backup do app encontrado.')),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: appBackupsState.entries.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, index) {
                  final entry = appBackupsState.entries[index];
                  return _AppBackupCard(
                    entry: entry,
                    onRestore: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (_) => AppModal(
                          icon: Icons.restore_page_rounded,
                          title: 'Restaurar backup do app',
                          body: const Text(
                            'A restauração do app sobrescreve dados administrativos (DB, players, permissões e histórico). Deseja continuar?',
                          ),
                          actions: [
                            AppButton(
                              label: 'Cancelar',
                              onPressed: () => Navigator.of(context).pop(false),
                              type: AppButtonType.textButton,
                              variant: AppVariant.danger,
                            ),
                            AppButton(
                              label: 'Confirmar',
                              onPressed: () => Navigator.of(context).pop(true),
                              variant: AppVariant.warning,
                              icon: Icons.check_rounded,
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        final strongConfirm = await _confirmAppRestore(entry);
                        if (!strongConfirm) return;
                        await _runAppAction(
                          action: () =>
                              appBackupsNotifier.restoreBackup(entry.path),
                          successMessage: 'Backup do app restaurado.',
                        );
                      }
                    },
                    onExport: () async {
                      final destination = await FilePicker.platform.saveFile(
                        dialogTitle: 'Exportar backup do app',
                        fileName: entry.name,
                        type: FileType.custom,
                        allowedExtensions: ['zip'],
                      );
                      if (destination == null) return;
                      await _runAppAction(
                        action: () async {
                          await appBackupsNotifier.exportBackup(
                            backupPath: entry.path,
                            destinationPath: destination,
                          );
                        },
                        successMessage: 'Backup exportado com sucesso.',
                      );
                    },
                    onDelete: () async {
                      await _runAppAction(
                        action: () =>
                            appBackupsNotifier.deleteBackup(entry.path),
                        successMessage: 'Backup do app removido.',
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _runAppAction({
    required Future<void> Function() action,
    String? successMessage,
  }) async {
    try {
      await action();
      if (!mounted || successMessage == null || successMessage.trim().isEmpty) {
        return;
      }
      _showFeedback(successMessage, isError: false);
    } catch (error) {
      if (!mounted) return;
      _showFeedback(_normalizeError(error), isError: true);
    }
  }

  Future<bool> _openAppBackupSettingsModal({
    required AppBackupSettings settings,
    required AppBackupSettingsNotifier notifier,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _AppBackupSettingsModal(
        initialSettings: settings,
        onSave: (next) async {
          await notifier.saveToDb(next);
        },
      ),
    );
    if (saved == true && mounted) {
      _showFeedback('Configuração do backup do app salva.');
      return true;
    }
    return false;
  }

  Future<bool> _confirmAppRestore(AppBackupEntry entry) async {
    final controller = TextEditingController();
    var canConfirm = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) {
          return AppModal(
            icon: Icons.warning_amber_rounded,
            title: 'Confirmação forte',
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Para restaurar ${entry.name}, digite exatamente: RESTAURAR APP',
                ),
                const SizedBox(height: 10),
                AppTextInput(
                  controller: controller,
                  hint: 'Digite RESTAURAR APP',
                  onChanged: (value) {
                    final next = value.trim().toUpperCase() == 'RESTAURAR APP';
                    if (next != canConfirm) {
                      setModalState(() => canConfirm = next);
                    }
                  },
                ),
              ],
            ),
            actions: [
              AppButton(
                label: 'Cancelar',
                onPressed: () => Navigator.of(context).pop(false),
                type: AppButtonType.textButton,
                variant: AppVariant.danger,
              ),
              AppButton(
                label: 'Restaurar agora',
                onPressed: () => Navigator.of(context).pop(true),
                isDisabled: !canConfirm,
                variant: AppVariant.warning,
                icon: Icons.restore_rounded,
              ),
            ],
          );
        },
      ),
    );
    controller.dispose();
    return confirmed == true;
  }

  String _normalizeError(Object error) {
    return error.toString().replaceFirst('Bad state: ', '').trim();
  }

  void _showFeedback(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary,
      ),
    );
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
                isDisabled:
                    !restoreEnabled ||
                    (entry.contentKind != BackupContentKind.full &&
                        entry.contentKind != BackupContentKind.world),
                onPressed:
                    restoreEnabled &&
                        (entry.contentKind == BackupContentKind.full ||
                            entry.contentKind == BackupContentKind.world)
                    ? onRestoreWorld
                    : null,
              ),
              AppButton(
                label: 'Restaurar completo',
                icon: Icons.restart_alt_rounded,
                variant: AppVariant.warning,
                transparent: true,
                isDisabled:
                    !restoreEnabled ||
                    (entry.contentKind != BackupContentKind.full &&
                        entry.contentKind != BackupContentKind.selective),
                onPressed:
                    restoreEnabled &&
                        (entry.contentKind == BackupContentKind.full ||
                            entry.contentKind == BackupContentKind.selective)
                    ? onRestoreFull
                    : null,
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

class _AppBackupSettingsModal extends StatefulWidget {
  const _AppBackupSettingsModal({
    required this.initialSettings,
    required this.onSave,
  });

  final AppBackupSettings initialSettings;
  final Future<void> Function(AppBackupSettings settings) onSave;

  @override
  State<_AppBackupSettingsModal> createState() =>
      _AppBackupSettingsModalState();
}

class _AppBackupSettingsModalState extends State<_AppBackupSettingsModal> {
  final TextEditingController _pathController = TextEditingController();
  final TextEditingController _cronController = TextEditingController();

  bool _autoEnabled = false;
  bool _saving = false;
  String? _pathError;
  String? _cronError;

  @override
  void initState() {
    super.initState();
    _pathController.text = widget.initialSettings.backupPath;
    _cronController.text = widget.initialSettings.cronExpression;
    _autoEnabled = widget.initialSettings.autoEnabled;
  }

  @override
  void dispose() {
    _pathController.dispose();
    _cronController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final path = _pathController.text.trim();
    final cron = _cronController.text.trim();

    final pathError = _validatePath(path);
    final cronError = _validateCron(cron, _autoEnabled);
    setState(() {
      _pathError = pathError;
      _cronError = cronError;
    });
    if (pathError != null || cronError != null) {
      return;
    }

    final settings = AppBackupSettings(
      backupPath: path,
      autoEnabled: _autoEnabled,
      cronExpression: cron.isEmpty ? '0 */6 * * *' : cron,
    );

    setState(() => _saving = true);
    try {
      await widget.onSave(settings);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  String? _validatePath(String path) {
    if (path.isEmpty) return null;
    final type = FileSystemEntity.typeSync(path, followLinks: false);
    if (type == FileSystemEntityType.file) {
      return 'Informe uma pasta, não um arquivo.';
    }
    return null;
  }

  String? _validateCron(String cron, bool autoEnabled) {
    if (!autoEnabled) return null;
    if (cron.isEmpty) {
      return 'Informe a expressão cron para backup automático.';
    }
    if (!CronMatcher.isValidExpression(cron)) {
      return 'Expressão cron inválida (5 campos).';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AppModal(
      icon: Icons.settings_suggest_rounded,
      title: 'Configurar backup do app',
      width: 680,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextInput(
            controller: _pathController,
            hint: r'Pasta dedicada (vazio = padrão do app)',
            prefixIcon: const Icon(Icons.folder_copy_rounded),
            onChanged: (_) {
              if (_pathError != null) {
                setState(() => _pathError = null);
              }
            },
          ),
          if (_pathError != null) ...[
            const SizedBox(height: 6),
            Text(
              _pathError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 12),
          AppSwitchCard(
            label: 'Backup automático do app',
            value: _autoEnabled,
            onChanged: (value) {
              setState(() {
                _autoEnabled = value;
                if (!_autoEnabled) {
                  _cronError = null;
                }
              });
            },
          ),
          const SizedBox(height: 12),
          AppTextInput(
            controller: _cronController,
            hint: 'Ex.: 0 */6 * * *',
            enabled: _autoEnabled,
            prefixIcon: const Icon(Icons.schedule_rounded),
            onChanged: (_) {
              if (_cronError != null) {
                setState(() => _cronError = null);
              }
            },
          ),
          if (_cronError != null) ...[
            const SizedBox(height: 6),
            Text(
              _cronError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        AppButton(
          label: 'Cancelar',
          onPressed: () => Navigator.of(context).pop(false),
          type: AppButtonType.textButton,
          variant: AppVariant.danger,
        ),
        AppButton(
          label: 'Salvar',
          onPressed: _save,
          isLoading: _saving,
          isDisabled: _saving,
          variant: AppVariant.success,
          icon: Icons.save_rounded,
        ),
      ],
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

enum _BackupsTab { server, app }

class _AppBackupCard extends StatelessWidget {
  const _AppBackupCard({
    required this.entry,
    required this.onRestore,
    required this.onExport,
    required this.onDelete,
  });

  final AppBackupEntry entry;
  final Future<void> Function() onRestore;
  final Future<void> Function() onExport;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('dd/MM/yyyy HH:mm').format(entry.modifiedAt);
    final sizeLabel = _formatSizeStatic(entry.sizeBytes);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Icon(
            Icons.phone_iphone_rounded,
            color: Theme.of(context).colorScheme.primary,
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
                  '$dateLabel • $sizeLabel',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              AppButton(
                label: 'Restaurar',
                icon: Icons.restore_rounded,
                variant: AppVariant.warning,
                transparent: true,
                onPressed: onRestore,
              ),
              AppButton(
                label: 'Exportar',
                icon: Icons.file_download_rounded,
                variant: AppVariant.info,
                transparent: true,
                onPressed: onExport,
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
}
