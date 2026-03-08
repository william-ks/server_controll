import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../components/badges/app_badge.dart';
import '../../../components/buttons/app_button.dart';
import '../../../components/inputs/app_text_input.dart';
import '../../../components/shared/app_variant.dart';
import '../../maintenance/models/maintenance_defaults.dart';
import '../../maintenance/providers/maintenance_provider.dart';
import '../models/config_files_settings.dart';
import '../providers/config_files_provider.dart';
import 'sticky_form_actions_bar.dart';

class MaintenanceSettingsTab extends ConsumerStatefulWidget {
  const MaintenanceSettingsTab({super.key});

  @override
  ConsumerState<MaintenanceSettingsTab> createState() =>
      _MaintenanceSettingsTabState();
}

class _MaintenanceSettingsTabState extends ConsumerState<MaintenanceSettingsTab> {
  final TextEditingController _motdTotalController = TextEditingController();
  final TextEditingController _motdAdminsController = TextEditingController();
  final TextEditingController _iconPathController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _iconExists = false;
  String? _initialSnapshot;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  @override
  void dispose() {
    _motdTotalController.dispose();
    _motdAdminsController.dispose();
    _iconPathController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await ref.read(configFilesProvider.notifier).refresh();
    final files = ref.read(configFilesProvider);
    final maintenance = ref.read(maintenanceProvider);

    _motdTotalController.text = maintenance.defaults.motdTotal;
    _motdAdminsController.text = maintenance.defaults.motdAdminsOnly;
    _iconPathController.text = files.maintenanceIconPath;
    await _validateIconPath();
    _initialSnapshot = _snapshot();

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  String _snapshot() {
    return [
      _motdTotalController.text.trim(),
      _motdAdminsController.text.trim(),
      _iconPathController.text.trim(),
    ].join('|');
  }

  bool get _isDirty =>
      _initialSnapshot != null && _snapshot() != _initialSnapshot;

  Future<void> _validateIconPath() async {
    final path = _iconPathController.text.trim();
    if (path.isEmpty) {
      _iconExists = false;
      return;
    }
    _iconExists = await File(path).exists();
  }

  Future<void> _pickIcon() async {
    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: 'Selecione a imagem de manutenção',
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
    );
    final sourcePath = picked?.files.single.path;
    if (sourcePath == null) return;
    final sourceFile = File(sourcePath);
    if (!sourceFile.existsSync()) return;

    final appDir = await getApplicationSupportDirectory();
    final targetDir = Directory(p.join(appDir.path, 'maintenance_assets'));
    await targetDir.create(recursive: true);
    final ext = p.extension(sourcePath).toLowerCase();
    final safeExt = ext.isEmpty ? '.png' : ext;
    final targetPath = p.join(targetDir.path, 'maintenance_default$safeExt');
    await sourceFile.copy(targetPath);
    _iconPathController.text = targetPath;
    await _validateIconPath();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _save() async {
    if (!_isDirty || _saving) return;
    setState(() => _saving = true);
    try {
      final notifier = ref.read(maintenanceProvider.notifier);
      final current = ref.read(maintenanceProvider).defaults;
      final defaults = MaintenanceDefaults(
        defaultMode: current.defaultMode,
        defaultCountdownSeconds: current.defaultCountdownSeconds,
        motdTotal: _motdTotalController.text.trim().isEmpty
            ? 'Servidor em manutenção'
            : _motdTotalController.text.trim(),
        motdAdminsOnly: _motdAdminsController.text.trim().isEmpty
            ? 'Servidor em manutenção (somente admins)'
            : _motdAdminsController.text.trim(),
        maintenanceIconPath: _iconPathController.text.trim(),
        adminNicknames: '',
      );
      await notifier.saveDefaults(defaults);

      final files = ref.read(configFilesProvider);
      final nextFiles = ConfigFilesSettings(
        serverPath: files.serverPath,
        ramMinGb: files.ramMinGb,
        ramMaxGb: files.ramMaxGb,
        fileServerName: files.fileServerName,
        javaCommand: files.javaCommand,
        jvmArgs: files.jvmArgs,
        autoRestartOnCrash: files.autoRestartOnCrash,
        restartWaitSeconds: files.restartWaitSeconds,
        maintenanceIconPath: _iconPathController.text.trim(),
      );
      await ref.read(configFilesProvider.notifier).saveToDb(nextFiles);

      _initialSnapshot = _snapshot();
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Manutenção',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                const SizedBox(height: 10),
                const AppBadge(
                  icon: Icons.info_outline_rounded,
                  variant: AppVariant.info,
                  title:
                      'Essas configurações são usadas quando o modo manutenção for ativado na Home.',
                ),
                const SizedBox(height: 14),
                AppTextInput(
                  controller: _motdTotalController,
                  label: 'Mensagem para manutenção total',
                  hint: 'Ex.: Servidor em manutenção',
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                AppTextInput(
                  controller: _motdAdminsController,
                  label: 'Mensagem para modo somente admins',
                  hint: 'Ex.: Somente admins do app',
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                AppTextInput(
                  controller: _iconPathController,
                  label: 'Imagem do modo manutenção',
                  hint: r'Ex.: C:\icons\maintenance.png',
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                AppButton(
                  label: 'Selecionar imagem',
                  icon: Icons.image_rounded,
                  variant: AppVariant.info,
                  transparent: true,
                  onPressed: _pickIcon,
                ),
                if (_iconPathController.text.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _iconExists
                          ? 'Imagem encontrada'
                          : 'Imagem não encontrada',
                      style: TextStyle(
                        color: _iconExists
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        StickyFormActionsBar(
          onSave: _save,
          onCancel: _isDirty ? _load : null,
          saveEnabled: _isDirty && !_saving,
          saveLoading: _saving,
        ),
      ],
    );
  }
}
