import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../components/buttons/app_button.dart';
import '../../../components/inputs/app_switch_card.dart';
import '../../../components/inputs/app_text_input.dart';
import '../../../components/modal/app_modal.dart';
import '../../../components/selects/app_select.dart';
import '../../../components/shared/app_variant.dart';
import '../../backup/providers/backup_config_provider.dart';
import '../models/schedule_action.dart';
import '../services/cron_matcher.dart';

class AddScheduleModal extends ConsumerStatefulWidget {
  const AddScheduleModal({super.key, required this.onCreate});

  final Future<void> Function({
    required String title,
    required String cronExpression,
    required ScheduleAction action,
    required bool withBackup,
  })
  onCreate;

  @override
  ConsumerState<AddScheduleModal> createState() => _AddScheduleModalState();
}

class _AddScheduleModalState extends ConsumerState<AddScheduleModal> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _cronController = TextEditingController();

  ScheduleAction _action = ScheduleAction.restartServer;
  bool _withBackup = false;
  bool _saving = false;
  String? _cronError;
  String? _titleError;

  @override
  void dispose() {
    _titleController.dispose();
    _cronController.dispose();
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
    final canEnableBackup =
        backupConfig.backupsEnabled &&
        backupConfig.backupPath.trim().isNotEmpty &&
        Directory(backupConfig.backupPath.trim()).existsSync();
    final effectiveWithBackup = canEnableBackup && _withBackup;

    setState(() {
      _saving = true;
      _cronError = null;
      _titleError = null;
    });
    try {
      await widget.onCreate(
        title: title,
        cronExpression: cron,
        action: _action,
        withBackup: effectiveWithBackup,
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final badgeColor = scheme.primary;
    final backupConfig = ref.watch(backupConfigProvider);
    final backupPathOk =
        backupConfig.backupPath.trim().isNotEmpty &&
        Directory(backupConfig.backupPath.trim()).existsSync();
    final canEnableBackup = backupConfig.backupsEnabled && backupPathOk;
    final effectiveWithBackup = canEnableBackup ? _withBackup : false;

    return AppModal(
      icon: Icons.schedule_rounded,
      title: 'Novo agendamento',
      width: 640,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: badgeColor.withValues(alpha: 0.28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Como funciona o agendamento',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: badgeColor.withValues(alpha: 0.94),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Defina uma expressão cron para executar tarefas automáticas no servidor (iniciar, reiniciar ou desligar). '
                  'Se o backup estiver ativo e válido, ele pode ser acoplado ao fluxo da ação.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w400,
                    color: badgeColor.withValues(alpha: 0.78),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: AppButton(
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
              ],
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
            value: effectiveWithBackup,
            onChanged: canEnableBackup
                ? (value) => setState(() => _withBackup = value)
                : null,
          ),
          if (!canEnableBackup)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Backup indisponível: verifique Config > Backup (ativos + pasta válida).',
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
