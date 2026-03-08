import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../components/badges/app_badge.dart';
import '../../../components/buttons/app_button.dart';
import '../../../components/inputs/app_switch_card.dart';
import '../../../components/inputs/app_text_input.dart';
import '../../../components/modal/app_modal.dart';
import '../../../components/selects/app_select.dart';
import '../../../components/shared/app_variant.dart';
import '../../backup/providers/backup_config_provider.dart';
import '../models/schedule_action.dart';
import '../models/schedule_backup_kind.dart';
import '../services/cron_matcher.dart';

class AddScheduleModal extends ConsumerStatefulWidget {
  const AddScheduleModal({super.key, required this.onCreate});

  final Future<void> Function({
    required String title,
    required String cronExpression,
    required ScheduleAction action,
    required bool withBackup,
    required ScheduleBackupKind backupKind,
    required List<String> selectiveRootEntries,
  })
  onCreate;

  @override
  ConsumerState<AddScheduleModal> createState() => _AddScheduleModalState();
}

class _AddScheduleModalState extends ConsumerState<AddScheduleModal> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _cronController = TextEditingController();
  final TextEditingController _selectiveController = TextEditingController();

  ScheduleAction _action = ScheduleAction.restartServer;
  ScheduleBackupKind _backupKind = ScheduleBackupKind.full;
  bool _withBackup = false;
  bool _saving = false;
  String? _cronError;
  String? _titleError;
  String? _backupError;
  String? _selectiveError;

  @override
  void dispose() {
    _titleController.dispose();
    _cronController.dispose();
    _selectiveController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final cron = _cronController.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = 'Informe o título do agendamento.');
      return;
    }
    if (!CronMatcher.isValidExpression(cron)) {
      setState(() => _cronError = 'Expressão crontab inválida. Use 5 campos.');
      return;
    }

    final backupConfig = ref.read(backupConfigProvider);
    final serverBackupReady =
        backupConfig.backupsEnabled &&
        backupConfig.backupPath.trim().isNotEmpty &&
        Directory(backupConfig.backupPath.trim()).existsSync();
    final requiresServerBackup = _backupKind != ScheduleBackupKind.app;
    final selectiveEntries = _parseSelectiveEntries(_selectiveController.text);
    final effectiveSelectiveEntries =
        _withBackup && _backupKind == ScheduleBackupKind.selective
        ? selectiveEntries
        : const <String>[];

    if (_withBackup && requiresServerBackup && !serverBackupReady) {
      setState(() {
        _backupError =
            'Backup de servidor indisponível: verifique Config > Backup (ativos + pasta válida).';
      });
      return;
    }
    if (_withBackup &&
        _backupKind == ScheduleBackupKind.selective &&
        selectiveEntries.isEmpty) {
      setState(() {
        _selectiveError =
            'Informe ao menos um item raiz para o backup seletivo.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _cronError = null;
      _titleError = null;
      _backupError = null;
      _selectiveError = null;
    });
    try {
      await widget.onCreate(
        title: title,
        cronExpression: cron,
        action: _action,
        withBackup: _withBackup,
        backupKind: _backupKind,
        selectiveRootEntries: effectiveSelectiveEntries,
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  List<String> _parseSelectiveEntries(String raw) {
    return raw
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final backupConfig = ref.watch(backupConfigProvider);
    final serverBackupReady =
        backupConfig.backupPath.trim().isNotEmpty &&
        Directory(backupConfig.backupPath.trim()).existsSync();
    final canUseServerBackup = backupConfig.backupsEnabled && serverBackupReady;
    final backupKindNeedsServer = _backupKind != ScheduleBackupKind.app;
    final showServerBackupWarning =
        _withBackup && backupKindNeedsServer && !canUseServerBackup;

    return AppModal(
      icon: Icons.schedule_rounded,
      title: 'Novo agendamento',
      width: 640,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppBadge(
            icon: Icons.info_outline_rounded,
            variant: AppVariant.primary,
            title: 'Como funciona o agendamento',
            description:
                'Defina uma expressão cron para executar tarefas automáticas no servidor (iniciar, reiniciar ou desligar). '
                'Se o backup estiver ativo e válido, ele pode ser acoplado ao fluxo da ação.',
            trailing: AppButton(
              label: 'Guia',
              type: AppButtonType.textIcon,
              transparent: true,
              variant: AppVariant.primary,
              icon: Icons.exit_to_app_rounded,
              onPressed: () => launchUrl(
                Uri.parse('https://crontab.guru/#*_*_*_*_*_*'),
                mode: LaunchMode.externalApplication,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Título do agendamento',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w400,
              color: scheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 6),
          AppTextInput(
            controller: _titleController,
            hint: 'Ex.: Reinício diário da madrugada',
            errorText: _titleError,
          ),
          const SizedBox(height: 14),
          Text(
            'Expressão cron',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w400,
              color: scheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 6),
          AppTextInput(
            controller: _cronController,
            hint: 'Ex.: */30 * * * *',
            errorText: _cronError,
          ),
          const SizedBox(height: 14),
          Text(
            'Ação',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w400,
              color: scheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 6),
          AppSelect<ScheduleAction>(
            value: _action,
            items: const [
              AppSelectItem(
                value: ScheduleAction.startServer,
                label: 'Iniciar servidor',
              ),
              AppSelectItem(
                value: ScheduleAction.restartServer,
                label: 'Reiniciar servidor',
              ),
              AppSelectItem(
                value: ScheduleAction.stopServer,
                label: 'Desligar servidor',
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _action = value);
              }
            },
          ),
          const SizedBox(height: 14),
          AppSwitchCard(
            label: 'Fazer backup',
            value: _withBackup,
            onChanged: (value) {
              setState(() {
                _withBackup = value;
                if (!value) {
                  _backupError = null;
                  _selectiveError = null;
                }
              });
            },
          ),
          if (_withBackup) ...[
            const SizedBox(height: 12),
            Text(
              'Tipo de backup',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w400,
                color: scheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 6),
            AppSelect<ScheduleBackupKind>(
              value: _backupKind,
              items: const [
                AppSelectItem(
                  value: ScheduleBackupKind.full,
                  label: 'Completo (servidor)',
                ),
                AppSelectItem(
                  value: ScheduleBackupKind.world,
                  label: 'Mundo (servidor)',
                ),
                AppSelectItem(
                  value: ScheduleBackupKind.selective,
                  label: 'Seletivo (servidor)',
                ),
                AppSelectItem(
                  value: ScheduleBackupKind.app,
                  label: 'App (dados administrativos)',
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _backupKind = value;
                  _backupError = null;
                  _selectiveError = null;
                });
              },
            ),
          ],
          if (_withBackup && _backupKind == ScheduleBackupKind.selective) ...[
            const SizedBox(height: 12),
            Text(
              'Itens raiz para backup seletivo',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w400,
                color: scheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 6),
            AppTextInput(
              controller: _selectiveController,
              hint: 'Ex.: world, plugins, server.properties',
              onChanged: (_) {
                if (_selectiveError != null) {
                  setState(() => _selectiveError = null);
                }
              },
            ),
          ],
          if (showServerBackupWarning)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Backup de servidor indisponível: verifique Config > Backup (ativos + pasta válida).',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (_backupError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _backupError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (_selectiveError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _selectiveError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
      actions: [
        AppButton(
          label: 'Cancelar',
          onPressed: () => Navigator.of(context).pop(),
          type: AppButtonType.textButton,
          variant: AppVariant.danger,
        ),
        AppButton(
          label: 'Adicionar',
          onPressed: _save,
          isLoading: _saving,
          isDisabled: _saving,
          variant: AppVariant.success,
          icon: Icons.add_rounded,
        ),
      ],
    );
  }
}
