import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/buttons/app_button.dart';
import '../../../components/inputs/app_switch_card.dart';
import '../../../components/inputs/app_text_input.dart';
import '../../../components/shared/app_variant.dart';
import '../../../modules/backup/models/backup_config_settings.dart';
import '../../../modules/backup/providers/backup_config_provider.dart';

class BackupSettingsTab extends ConsumerStatefulWidget {
  const BackupSettingsTab({super.key});

  @override
  ConsumerState<BackupSettingsTab> createState() => _BackupSettingsTabState();
}

class _BackupSettingsTabState extends ConsumerState<BackupSettingsTab> {
  final TextEditingController _backupPathController = TextEditingController();
  final TextEditingController _maxBackupsController = TextEditingController();

  Timer? _pathDebounce;

  bool _backupsEnabled = false;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _pathExists = false;
  String? _maxError;
  String? _initialSnapshot;

  @override
  void initState() {
    super.initState();
    _backupPathController.addListener(_onPathChanged);
    _maxBackupsController.addListener(_onMaxChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFromProvider(refresh: true);
    });
  }

  @override
  void dispose() {
    _pathDebounce?.cancel();
    _backupPathController.dispose();
    _maxBackupsController.dispose();
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
    _validateMaxBackups();
    _initialSnapshot = _snapshot();

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _applySettings(BackupConfigSettings settings) {
    _backupPathController.text = settings.backupPath;
    _maxBackupsController.text = settings.maxBackups;
    _backupsEnabled = settings.backupsEnabled;
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

  void _validateMaxBackups() {
    final value = int.tryParse(_maxBackupsController.text.trim());
    if (_maxBackupsController.text.trim().isEmpty) {
      _maxError = 'Informe o máximo de backups.';
      return;
    }
    if (value == null) {
      _maxError = 'Informe um valor numérico.';
      return;
    }
    if (value < 1) {
      _maxError = 'O mínimo permitido é 1.';
      return;
    }
    _maxError = null;
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

  void _onMaxChanged() {
    _validateMaxBackups();
    setState(() {});
  }

  String _snapshot() {
    return [
      _backupPathController.text.trim(),
      _backupsEnabled ? '1' : '0',
      _maxBackupsController.text.trim(),
    ].join('|');
  }

  bool get _isDirty =>
      _initialSnapshot != null && _snapshot() != _initialSnapshot;

  bool get _isValid {
    final hasValidPath = !_backupsEnabled || _pathExists;
    return hasValidPath && _maxError == null;
  }

  Future<void> _save() async {
    if (!_isDirty || !_isValid || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      final settings = BackupConfigSettings(
        backupPath: _backupPathController.text.trim(),
        backupsEnabled: _backupsEnabled,
        maxBackups: _maxBackupsController.text.trim(),
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
    final color = AppVariantPalette.resolve(variant);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final showPathBadge = _backupPathController.text.trim().isNotEmpty;

    return SingleChildScrollView(
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
              text: _pathExists ? 'PASTA ENCONTRADA' : 'PASTA NÃO ENCONTRADA',
              variant: _pathExists ? AppVariant.success : AppVariant.danger,
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
          const SizedBox(height: 14),
          AppSwitchCard(
            label: 'Backups ativos:',
            value: _backupsEnabled,
            onChanged: (value) => setState(() => _backupsEnabled = value),
          ),
          const SizedBox(height: 14),
          _fieldLabel('Máximo de backups:'),
          AppTextInput(
            controller: _maxBackupsController,
            hint: 'Ex.: 5',
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
          ),
          if (_maxError != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _maxError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (_isDirty)
                AppButton(
                  label: 'Cancelar',
                  onPressed: _cancelChanges,
                  variant: AppVariant.danger,
                  transparent: true,
                  icon: Icons.close_rounded,
                ),
              if (_isDirty) const SizedBox(width: 10),
              AppButton(
                label: 'Salvar',
                onPressed: _save,
                isLoading: _isSaving,
                isDisabled: !_isDirty || !_isValid || _isSaving,
                variant: AppVariant.success,
                icon: Icons.save_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
