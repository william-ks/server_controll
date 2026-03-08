import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/badges/app_badge.dart';
import '../../../components/inputs/app_switch_card.dart';
import '../../../components/inputs/app_text_input.dart';
import '../../../components/shared/app_variant.dart';
import '../../../modules/backup/models/backup_capacity_status.dart';
import '../../../modules/backup/models/backup_config_settings.dart';
import '../../../modules/backup/providers/backup_config_provider.dart';
import '../../../modules/backup/providers/backups_provider.dart';
import 'sticky_form_actions_bar.dart';

class BackupSettingsTab extends ConsumerStatefulWidget {
  const BackupSettingsTab({super.key});

  @override
  ConsumerState<BackupSettingsTab> createState() => _BackupSettingsTabState();
}

class _BackupSettingsTabState extends ConsumerState<BackupSettingsTab> {
  final TextEditingController _backupPathController = TextEditingController();
  final TextEditingController _retentionMaxGbController =
      TextEditingController();
  final TextEditingController _warnPercentController = TextEditingController();

  Timer? _pathDebounce;

  bool _backupsEnabled = false;
  bool _autoCleanupEnabled = true;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _pathExists = false;
  String? _retentionError;
  String? _warnPercentError;
  String? _initialSnapshot;

  @override
  void initState() {
    super.initState();
    _backupPathController.addListener(_onPathChanged);
    _retentionMaxGbController.addListener(_onRetentionChanged);
    _warnPercentController.addListener(_onWarnChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFromProvider(refresh: true);
    });
  }

  @override
  void dispose() {
    _pathDebounce?.cancel();
    _backupPathController.dispose();
    _retentionMaxGbController.dispose();
    _warnPercentController.dispose();
    super.dispose();
  }

  Future<void> _loadFromProvider({required bool refresh}) async {
    setState(() => _isLoading = true);
    final notifier = ref.read(backupConfigProvider.notifier);
    if (refresh) {
      await notifier.refresh();
    }

    final settings = ref.read(backupConfigProvider);
    _applySettings(settings);
    await _validatePath();
    _validateRetention();
    _validateWarnPercent();
    _initialSnapshot = _snapshot();

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _applySettings(BackupConfigSettings settings) {
    _backupPathController.text = settings.backupPath;
    _retentionMaxGbController.text = settings.retentionMaxGb;
    _warnPercentController.text = '${settings.capacityWarnThresholdPercent}';
    _backupsEnabled = settings.backupsEnabled;
    _autoCleanupEnabled = settings.autoCleanupEnabled;
  }

  Future<void> _validatePath() async {
    final backupPath = _backupPathController.text.trim();
    if (backupPath.isEmpty) {
      setState(() => _pathExists = false);
      return;
    }
    final exists = await Directory(backupPath).exists();
    if (mounted) {
      setState(() => _pathExists = exists);
    }
  }

  void _validateRetention() {
    final raw = _retentionMaxGbController.text.trim();
    final value = double.tryParse(raw.replaceAll(',', '.'));
    if (raw.isEmpty) {
      _retentionError = 'Informe o limite em GB (0 para ilimitado).';
      return;
    }
    if (value == null) {
      _retentionError = 'Informe um valor numérico válido.';
      return;
    }
    if (value < 0) {
      _retentionError = 'O valor deve ser maior ou igual a zero.';
      return;
    }
    _retentionError = null;
  }

  void _validateWarnPercent() {
    final value = int.tryParse(_warnPercentController.text.trim());
    if (_warnPercentController.text.trim().isEmpty) {
      _warnPercentError = 'Informe o percentual de alerta.';
      return;
    }
    if (value == null) {
      _warnPercentError = 'Informe um valor numérico.';
      return;
    }
    if (value < 1 || value > 99) {
      _warnPercentError = 'Use um valor entre 1 e 99.';
      return;
    }
    _warnPercentError = null;
  }

  void _onPathChanged() {
    _pathDebounce?.cancel();
    _pathDebounce = Timer(const Duration(milliseconds: 320), () async {
      await _validatePath();
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _onRetentionChanged() {
    _validateRetention();
    setState(() {});
  }

  void _onWarnChanged() {
    _validateWarnPercent();
    setState(() {});
  }

  String _snapshot() {
    return [
      _backupPathController.text.trim(),
      _backupsEnabled ? '1' : '0',
      _retentionMaxGbController.text.trim(),
      _autoCleanupEnabled ? '1' : '0',
      _warnPercentController.text.trim(),
    ].join('|');
  }

  bool get _isDirty =>
      _initialSnapshot != null && _snapshot() != _initialSnapshot;

  bool get _isValid {
    final hasValidPath = !_backupsEnabled || _pathExists;
    return hasValidPath && _retentionError == null && _warnPercentError == null;
  }

  Future<void> _save() async {
    if (!_isDirty || !_isValid || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      final settings = BackupConfigSettings(
        backupPath: _backupPathController.text.trim(),
        backupsEnabled: _backupsEnabled,
        retentionMaxGb: _retentionMaxGbController.text.trim(),
        autoCleanupEnabled: _autoCleanupEnabled,
        capacityWarnThresholdPercent:
            int.tryParse(_warnPercentController.text.trim()) ?? 80,
      );
      await ref.read(backupConfigProvider.notifier).saveToDb(settings);
      _initialSnapshot = _snapshot();
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _cancelChanges() async {
    await _loadFromProvider(refresh: true);
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.secondary,
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w400),
      ),
    );
  }

  Widget _validationBadge({
    required String text,
    required AppVariant variant,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: AppBadge(title: text, icon: icon, variant: variant),
    );
  }

  @override
  Widget build(BuildContext context) {
    final capacity = ref.watch(backupsProvider).capacity;
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final showPathBadge = _backupPathController.text.trim().isNotEmpty;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('Backups'),
                _fieldLabel('Pasta para backup:'),
                AppTextInput(
                  controller: _backupPathController,
                  hint: r'Ex.: D:\MineControl\backups',
                  prefixIcon: const Icon(Icons.folder_copy_rounded),
                  onChanged: (_) => setState(() {}),
                ),
                if (showPathBadge)
                  _validationBadge(
                    text: _pathExists
                        ? 'PASTA ENCONTRADA'
                        : 'PASTA NÃO ENCONTRADA',
                    variant: _pathExists
                        ? AppVariant.success
                        : AppVariant.danger,
                    icon: _pathExists
                        ? Icons.check_circle_outline_rounded
                        : Icons.close_rounded,
                  ),
                if (!showPathBadge)
                  _validationBadge(
                    text: 'INFORME UMA PASTA',
                    variant: AppVariant.info,
                    icon: Icons.info_outline_rounded,
                  ),
                if (capacity != null && capacity.hasLimit)
                  _validationBadge(
                    text: _capacityText(capacity),
                    variant: switch (capacity.level) {
                      BackupCapacityLevel.normal => AppVariant.success,
                      BackupCapacityLevel.warning => AppVariant.warning,
                      BackupCapacityLevel.reached => AppVariant.warning,
                      BackupCapacityLevel.exceeded => AppVariant.danger,
                    },
                    icon: Icons.storage_rounded,
                  ),
                const SizedBox(height: 14),
                AppSwitchCard(
                  label: 'Backups ativos:',
                  value: _backupsEnabled,
                  onChanged: (value) => setState(() => _backupsEnabled = value),
                ),
                const SizedBox(height: 14),
                _fieldLabel('Limite de retenção (GB):'),
                AppTextInput(
                  controller: _retentionMaxGbController,
                  hint: 'Ex.: 0 (ilimitado), 10, 25.5',
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
                if (_retentionError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _retentionError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
                AppSwitchCard(
                  label: 'Limpeza automática quando exceder limite',
                  value: _autoCleanupEnabled,
                  onChanged: (value) =>
                      setState(() => _autoCleanupEnabled = value),
                ),
                const SizedBox(height: 14),
                _fieldLabel('Alerta de capacidade (%)'),
                AppTextInput(
                  controller: _warnPercentController,
                  hint: 'Ex.: 80',
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
                if (_warnPercentError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _warnPercentError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        StickyFormActionsBar(
          onSave: _save,
          onCancel: _isDirty ? _cancelChanges : null,
          saveEnabled: _isDirty && _isValid && !_isSaving,
          saveLoading: _isSaving,
        ),
      ],
    );
  }

  String _capacityText(BackupCapacityStatus capacity) {
    String format(int value) {
      final megaBytes = value / (1024 * 1024);
      if (megaBytes > 24) {
        final gigaBytes = value / (1024 * 1024 * 1024);
        return '${gigaBytes.toStringAsFixed(2)} GB';
      }
      return '${megaBytes.toStringAsFixed(2)} MB';
    }

    return 'Uso atual: ${format(capacity.usedBytes)} / ${format(capacity.limitBytes)} (${capacity.usedPercent.toStringAsFixed(1)}%)';
  }
}
