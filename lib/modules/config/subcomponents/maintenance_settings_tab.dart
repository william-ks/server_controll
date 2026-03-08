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
  static const String _maintenanceIconFileName = 'maintenance_default';
  static const List<String> _imageExtensions = ['png', 'jpg', 'jpeg', 'webp'];
  static const List<String> _serverIconCandidates = [
    'server-icon.png',
    'server-icon.jpg',
    'server-icon.jpeg',
    'server-icon.webp',
  ];

  final TextEditingController _motdTotalController = TextEditingController();
  final TextEditingController _motdAdminsController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _isHandlingIcon = false;
  String? _initialSnapshot;
  String _maintenanceIconPath = '';
  File? _maintenanceIconFile;
  File? _serverIconFallbackFile;
  String _serverPath = '';

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
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await ref.read(configFilesProvider.notifier).refresh();
    final files = ref.read(configFilesProvider);
    final maintenance = ref.read(maintenanceProvider);
    _serverPath = files.serverPath.trim();

    _motdTotalController.text = maintenance.defaults.motdTotal;
    _motdAdminsController.text = maintenance.defaults.motdAdminsOnly;
    _maintenanceIconPath = files.maintenanceIconPath.trim();
    await _loadVisualState();
    _initialSnapshot = _snapshot();

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  String _snapshot() {
    return [
      _motdTotalController.text.trim(),
      _motdAdminsController.text.trim(),
      _maintenanceIconPath.trim(),
    ].join('|');
  }

  bool get _isDirty =>
      _initialSnapshot != null && _snapshot() != _initialSnapshot;

  Future<void> _loadVisualState() async {
    _maintenanceIconFile = await _resolveExistingFile(_maintenanceIconPath);
    _serverIconFallbackFile = _resolveServerIconFile(_serverPath);
  }

  Future<void> _pickIcon() async {
    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: 'Selecione a imagem de manutenção',
      type: FileType.custom,
      allowedExtensions: _imageExtensions,
    );
    final sourcePath = picked?.files.single.path;
    if (sourcePath == null) return;
    final sourceFile = File(sourcePath);
    if (!sourceFile.existsSync()) return;

    setState(() => _isHandlingIcon = true);
    try {
    final appDir = await getApplicationSupportDirectory();
    final targetDir = Directory(p.join(appDir.path, 'maintenance_assets'));
    await targetDir.create(recursive: true);
    final ext = p.extension(sourcePath).toLowerCase();
    final safeExt = ext.isEmpty ? '.png' : ext;
      await _deleteOldMaintenanceCopies(targetDir);
      final targetPath = p.join(
        targetDir.path,
        '$_maintenanceIconFileName$safeExt',
      );
    await sourceFile.copy(targetPath);
      _maintenanceIconPath = targetPath;
      await _loadVisualState();
      _showMessage('Visual de manutenção atualizado.');
    } catch (_) {
      _showMessage('Não foi possível atualizar o visual de manutenção.');
    } finally {
      if (mounted) {
        setState(() => _isHandlingIcon = false);
      }
    }
  }

  Future<void> _removeIcon() async {
    if (_isHandlingIcon) return;
    setState(() => _isHandlingIcon = true);
    try {
      final current = await _resolveExistingFile(_maintenanceIconPath);
      if (current != null && await current.exists()) {
        await current.delete();
      }
      _maintenanceIconPath = '';
      await _loadVisualState();
      _showMessage('Visual de manutenção removido. O servidor usará o visual padrão.');
    } catch (_) {
      _showMessage('Não foi possível remover o visual de manutenção.');
    } finally {
      if (mounted) {
        setState(() => _isHandlingIcon = false);
      }
    }
  }

  Future<void> _deleteOldMaintenanceCopies(Directory targetDir) async {
    for (final ext in _imageExtensions) {
      final file = File(p.join(targetDir.path, '$_maintenanceIconFileName.$ext'));
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<File?> _resolveExistingFile(String path) async {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return null;
    final file = File(trimmed);
    if (await file.exists()) {
      return file;
    }
    return null;
  }

  File? _resolveServerIconFile(String serverPath) {
    if (serverPath.trim().isEmpty) {
      return null;
    }
    for (final fileName in _serverIconCandidates) {
      final file = File(p.join(serverPath, fileName));
      if (file.existsSync()) {
        return file;
      }
    }
    return null;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
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
        maintenanceIconPath: _maintenanceIconPath.trim(),
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
        maintenanceIconPath: _maintenanceIconPath.trim(),
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
    final previewFile = _maintenanceIconFile ?? _serverIconFallbackFile;
    final usingServerDefault =
        _maintenanceIconFile == null && _serverIconFallbackFile != null;
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
                Text(
                  'Visual do servidor em manutenção',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.outline.withValues(alpha: 0.5),
                        ),
                      ),
                      child: ClipOval(
                        child: previewFile == null
                            ? Icon(
                                Icons.image_not_supported_rounded,
                                size: 30,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.45),
                              )
                            : Image.file(
                                previewFile,
                                fit: BoxFit.cover,
                                errorBuilder: (_, error, stackTrace) {
                                  return Icon(
                                    Icons.broken_image_rounded,
                                    size: 30,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.45),
                                  );
                                },
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _maintenanceIconFile != null
                                ? 'Imagem própria de manutenção configurada.'
                                : usingServerDefault
                                ? 'Sem imagem de manutenção. O visual padrão do servidor será usado.'
                                : 'Nenhuma imagem disponível no momento.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            children: [
                              AppButton(
                                label: _maintenanceIconFile == null
                                    ? 'Escolher foto'
                                    : 'Editar foto',
                                onPressed: _pickIcon,
                                isLoading: _isHandlingIcon,
                                isDisabled: _isHandlingIcon,
                                icon: Icons.upload_rounded,
                              ),
                              AppButton(
                                label: 'Remover',
                                onPressed: _removeIcon,
                                variant: AppVariant.danger,
                                transparent: true,
                                isDisabled:
                                    _maintenanceIconFile == null ||
                                    _isHandlingIcon,
                                icon: Icons.delete_outline_rounded,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Servidor',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Defina as mensagens que serão aplicadas ao servidor durante a manutenção.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
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
