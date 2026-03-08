import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../components/badges/app_badge.dart';
import '../../../components/buttons/app_button.dart';
import '../../../components/inputs/app_switch_card.dart';
import '../../../components/inputs/app_text_input.dart';
import '../../../components/selects/app_select.dart';
import '../../../components/shared/app_variant.dart';
import '../models/config_properties_settings.dart';
import '../models/server_properties_field_catalog.dart';
import '../providers/config_files_provider.dart';
import '../providers/config_properties_provider.dart';
import '../services/server_properties_service.dart';
import 'sticky_form_actions_bar.dart';

class PropertiesSettingsTab extends ConsumerStatefulWidget {
  const PropertiesSettingsTab({super.key});

  @override
  ConsumerState<PropertiesSettingsTab> createState() =>
      _PropertiesSettingsTabState();
}

class _PropertiesSettingsTabState extends ConsumerState<PropertiesSettingsTab> {
  static const String _serverIconFileName = 'server-icon.png';
  static const List<String> _serverIconCandidates = [
    'server-icon.png',
    'server-icon.jpg',
    'server-icon.jpeg',
    'server-icon.webp',
  ];

  final ServerPropertiesService _service = ServerPropertiesService();
  final Map<String, String> _values = <String, String>{};
  final Map<String, String?> _errors = <String, String?>{};
  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isHandlingIcon = false;
  String _serverPath = '';
  bool _serverPropertiesFound = false;
  String? _initialSnapshot;
  File? _serverIconFile;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final configFiles = ref.read(configFilesProvider);
    _serverPath = configFiles.serverPath.trim();
    _serverPropertiesFound =
        _serverPath.isNotEmpty &&
        File(p.join(_serverPath, 'server.properties')).existsSync();

    final raw = await _service.loadRawProperties(_serverPath) ?? {};
    _values.clear();
    for (final field in serverPropertiesCatalog) {
      _values[field.key] = raw[field.key] ?? field.defaultValue;
    }
    _resetControllers();

    _loadServerIconFromDisk();
    _validateAll();
    _initialSnapshot = _snapshot();

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  bool get _isDirty =>
      _initialSnapshot != null && _snapshot() != _initialSnapshot;

  bool get _canSave =>
      _serverPropertiesFound &&
      _errors.values.every((error) => error == null) &&
      _isDirty;

  String _snapshot() {
    final keys = _values.keys.toList()..sort();
    return keys.map((key) => '$key=${_values[key] ?? ''}').join('|');
  }

  void _validateAll() {
    _errors.clear();
    for (final field in serverPropertiesCatalog) {
      final value = _values[field.key] ?? field.defaultValue;
      _errors[field.key] = _service.validateByCatalog(field, value);
    }
  }

  void _resetControllers() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    for (final field in serverPropertiesCatalog) {
      if (field.type == ServerPropertyFieldType.string ||
          field.type == ServerPropertyFieldType.integer) {
        _controllers[field.key] = TextEditingController(
          text: _values[field.key] ?? field.defaultValue,
        );
      }
    }
  }

  Future<void> _save() async {
    _validateAll();
    if (!_canSave || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      await _service.saveManagedProperties(
        serverPath: _serverPath,
        managed: _values,
      );

      final mapped = ConfigPropertiesSettings(
        serverName: _values[ServerPropertiesService.keyLevelName] ?? 'world',
        description:
            _values[ServerPropertiesService.keyMotd] ?? 'A Minecraft Server',
        seed: _values[ServerPropertiesService.keyLevelSeed] ?? '',
        hardcore:
            (_values[ServerPropertiesService.keyHardcore] ?? 'false') == 'true',
        gameMode: _values[ServerPropertiesService.keyGamemode] ?? 'survival',
        maxPlayers: _values[ServerPropertiesService.keyMaxPlayers] ?? '20',
        pvp: (_values[ServerPropertiesService.keyPvp] ?? 'true') == 'true',
        whitelist:
            (_values[ServerPropertiesService.keyWhitelist] ?? 'false') ==
            'true',
        viewDistance: _values[ServerPropertiesService.keyViewDistance] ?? '10',
        simulationDistance:
            _values[ServerPropertiesService.keySimulationDistance] ?? '10',
      );
      await ref.read(configPropertiesProvider.notifier).saveToDb(mapped);
      _initialSnapshot = _snapshot();
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _cancel() async {
    await _load();
  }

  void _loadServerIconFromDisk() {
    if (_serverPath.isEmpty) {
      _serverIconFile = null;
      return;
    }
    for (final fileName in _serverIconCandidates) {
      final file = File(p.join(_serverPath, fileName));
      if (file.existsSync()) {
        _serverIconFile = file;
        return;
      }
    }
    _serverIconFile = null;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _pickServerIcon() async {
    if (_serverPath.isEmpty) {
      _showMessage('Defina o path do servidor em Config > Arquivos.');
      return;
    }
    final serverDir = Directory(_serverPath);
    if (!serverDir.existsSync()) {
      _showMessage('Diretório do servidor não encontrado.');
      return;
    }

    setState(() => _isHandlingIcon = true);
    try {
      final picked = await FilePicker.platform.pickFiles(
        dialogTitle: 'Selecione a imagem do servidor',
        type: FileType.custom,
        allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
      );
      if (picked == null ||
          picked.files.isEmpty ||
          picked.files.single.path == null) {
        return;
      }

      final sourcePath = picked.files.single.path!;
      final targetPath = p.join(_serverPath, _serverIconFileName);
      final sourceFile = File(sourcePath);
      if (!sourceFile.existsSync()) {
        _showMessage('Arquivo selecionado não foi encontrado.');
        return;
      }

      if (p.normalize(sourcePath) != p.normalize(targetPath)) {
        await sourceFile.copy(targetPath);
      }

      for (final fileName in _serverIconCandidates) {
        if (fileName == _serverIconFileName) continue;
        final file = File(p.join(_serverPath, fileName));
        if (file.existsSync()) {
          await file.delete();
        }
      }

      setState(() => _serverIconFile = File(targetPath));
      _showMessage('Imagem do servidor atualizada.');
    } catch (_) {
      _showMessage('Não foi possível atualizar a imagem do servidor.');
    } finally {
      if (mounted) {
        setState(() => _isHandlingIcon = false);
      }
    }
  }

  Future<void> _removeServerIcon() async {
    if (_serverPath.isEmpty || _isHandlingIcon) return;
    setState(() => _isHandlingIcon = true);
    try {
      for (final fileName in _serverIconCandidates) {
        final file = File(p.join(_serverPath, fileName));
        if (file.existsSync()) {
          await file.delete();
        }
      }
      setState(() => _serverIconFile = null);
      _showMessage('Imagem do servidor removida.');
    } catch (_) {
      _showMessage('Não foi possível remover a imagem do servidor.');
    } finally {
      if (mounted) {
        setState(() => _isHandlingIcon = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final grouped = <String, List<ServerPropertyFieldDefinition>>{};
    for (final field in serverPropertiesCatalog) {
      grouped.putIfAbsent(field.group, () => []).add(field);
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!_serverPropertiesFound)
                  AppBadge(
                    icon: Icons.error_outline_rounded,
                    variant: AppVariant.danger,
                    title: 'server.properties não encontrado',
                    description: _serverPath.isEmpty
                        ? 'Defina o path do servidor em Config > Arquivos.'
                        : 'Caminho esperado: ${p.join(_serverPath, 'server.properties')}',
                  ),
                if (!_serverPropertiesFound) const SizedBox(height: 12),
                const AppBadge(
                  icon: Icons.info_outline_rounded,
                  variant: AppVariant.info,
                  title:
                      'As propriedades exigem reinício do servidor para ter efeito.',
                ),
                const SizedBox(height: 14),
                Text(
                  'Visual do servidor',
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
                        child: _serverIconFile == null
                            ? Icon(
                                Icons.image_not_supported_rounded,
                                size: 30,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.45),
                              )
                            : Image.file(
                                _serverIconFile!,
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
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        AppButton(
                          label: _serverIconFile == null
                              ? 'Escolher foto'
                              : 'Editar foto',
                          onPressed: _pickServerIcon,
                          isLoading: _isHandlingIcon,
                          isDisabled: _isHandlingIcon,
                          icon: Icons.upload_rounded,
                        ),
                        AppButton(
                          label: 'Remover',
                          onPressed: _removeServerIcon,
                          variant: AppVariant.danger,
                          transparent: true,
                          isDisabled:
                              _serverIconFile == null || _isHandlingIcon,
                          icon: Icons.delete_outline_rounded,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                for (final group in grouped.entries) ...[
                  Text(
                    group.key,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final field in group.value) ...[
                    Text(
                      field.label,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      field.description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildField(field),
                    if (_errors[field.key] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _errors[field.key]!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        StickyFormActionsBar(
          onSave: _save,
          onCancel: _isDirty ? _cancel : null,
          saveEnabled: _canSave && !_isSaving,
          saveLoading: _isSaving,
        ),
      ],
    );
  }

  Widget _buildField(ServerPropertyFieldDefinition field) {
    final value = _values[field.key] ?? field.defaultValue;
    switch (field.type) {
      case ServerPropertyFieldType.boolean:
        return AppSwitchCard(
          label: field.label,
          value: value.toLowerCase() == 'true',
          onChanged: (next) {
            setState(() {
              _values[field.key] = next ? 'true' : 'false';
              _errors[field.key] = _service.validateByCatalog(
                field,
                _values[field.key]!,
              );
            });
          },
        );
      case ServerPropertyFieldType.enumeration:
        final options = field.options.isEmpty
            ? <String>[field.defaultValue]
            : field.options;
        final selected = options.contains(value) ? value : options.first;
        if (!options.contains(value)) {
          _values[field.key] = selected;
        }
        return AppSelect<String>(
          value: selected,
          items: options
              .map((option) => AppSelectItem(value: option, label: option))
              .toList(),
          onChanged: (next) {
            if (next == null) return;
            setState(() {
              _values[field.key] = next;
              _errors[field.key] = _service.validateByCatalog(field, next);
            });
          },
        );
      case ServerPropertyFieldType.integer:
      case ServerPropertyFieldType.string:
        final controller = _controllers[field.key]!;
        return AppTextInput(
          controller: controller,
          keyboardType: field.type == ServerPropertyFieldType.integer
              ? TextInputType.number
              : TextInputType.text,
          onChanged: (next) {
            setState(() {
              _values[field.key] = next;
              _errors[field.key] = _service.validateByCatalog(field, next);
            });
          },
        );
    }
  }
}
