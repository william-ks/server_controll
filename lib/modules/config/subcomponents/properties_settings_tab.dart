import 'dart:io';

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
import '../providers/config_files_provider.dart';
import '../providers/config_properties_provider.dart';

class PropertiesSettingsTab extends ConsumerStatefulWidget {
  const PropertiesSettingsTab({super.key});

  @override
  ConsumerState<PropertiesSettingsTab> createState() =>
      _PropertiesSettingsTabState();
}

class _PropertiesSettingsTabState extends ConsumerState<PropertiesSettingsTab> {
  final TextEditingController _serverNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _seedController = TextEditingController();
  final TextEditingController _maxPlayersController = TextEditingController();
  final TextEditingController _viewDistanceController = TextEditingController();
  final TextEditingController _simulationDistanceController =
      TextEditingController();

  String _gameMode = 'survival';
  bool _hardcore = false;
  bool _pvp = true;
  bool _whitelist = false;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _initialSnapshot;
  String? _numbersError;
  String _serverPath = '';
  bool _serverPropertiesFound = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  @override
  void dispose() {
    _serverNameController.dispose();
    _descriptionController.dispose();
    _seedController.dispose();
    _maxPlayersController.dispose();
    _viewDistanceController.dispose();
    _simulationDistanceController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final configFiles = ref.read(configFilesProvider);
    _serverPath = configFiles.serverPath.trim();
    _serverPropertiesFound =
        _serverPath.isNotEmpty &&
        File(p.join(_serverPath, 'server.properties')).existsSync();

    await ref
        .read(configPropertiesProvider.notifier)
        .loadFromSources(_serverPath);
    final settings = ref.read(configPropertiesProvider);
    _applySettings(settings);
    _validateNumbers();
    _initialSnapshot = _snapshot();

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _applySettings(ConfigPropertiesSettings settings) {
    _serverNameController.text = settings.serverName;
    _descriptionController.text = settings.description;
    _seedController.text = settings.seed;
    _hardcore = settings.hardcore;
    _gameMode = settings.gameMode;
    _maxPlayersController.text = settings.maxPlayers;
    _pvp = settings.pvp;
    _whitelist = settings.whitelist;
    _viewDistanceController.text = settings.viewDistance;
    _simulationDistanceController.text = settings.simulationDistance;
  }

  void _validateNumbers() {
    final maxPlayers = int.tryParse(_maxPlayersController.text.trim());
    final viewDistance = int.tryParse(_viewDistanceController.text.trim());
    final simulationDistance = int.tryParse(
      _simulationDistanceController.text.trim(),
    );

    if (maxPlayers == null || maxPlayers < 1) {
      _numbersError = 'Max players deve ser numerico e >= 1.';
      return;
    }
    if (viewDistance == null || viewDistance < 2) {
      _numbersError = 'View distance deve ser numerico e >= 2.';
      return;
    }
    if (simulationDistance == null || simulationDistance < 2) {
      _numbersError = 'Simulation distance deve ser numerico e >= 2.';
      return;
    }
    _numbersError = null;
  }

  String _snapshot() {
    return [
      _serverNameController.text.trim(),
      _descriptionController.text.trim(),
      _seedController.text.trim(),
      _hardcore ? '1' : '0',
      _gameMode,
      _maxPlayersController.text.trim(),
      _pvp ? '1' : '0',
      _whitelist ? '1' : '0',
      _viewDistanceController.text.trim(),
      _simulationDistanceController.text.trim(),
    ].join('|');
  }

  bool get _isDirty =>
      _initialSnapshot != null && _snapshot() != _initialSnapshot;

  bool get _canSave => _serverPropertiesFound && _numbersError == null;

  ConfigPropertiesSettings _toSettings() {
    return ConfigPropertiesSettings(
      serverName: _serverNameController.text.trim(),
      description: _descriptionController.text.trim(),
      seed: _seedController.text.trim(),
      hardcore: _hardcore,
      gameMode: _gameMode,
      maxPlayers: _maxPlayersController.text.trim(),
      pvp: _pvp,
      whitelist: _whitelist,
      viewDistance: _viewDistanceController.text.trim(),
      simulationDistance: _simulationDistanceController.text.trim(),
    );
  }

  Future<void> _save() async {
    _validateNumbers();
    if (!_isDirty || !_canSave || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      final settings = _toSettings();
      await ref
          .read(configPropertiesProvider.notifier)
          .saveEverywhere(serverPath: _serverPath, settings: settings);
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppBadge(
            icon: _serverPropertiesFound
                ? Icons.check_circle_outline_rounded
                : Icons.error_outline_rounded,
            variant: _serverPropertiesFound
                ? AppVariant.success
                : AppVariant.danger,
            title: _serverPropertiesFound
                ? 'server.properties encontrado'
                : 'server.properties nao encontrado',
            description: _serverPath.isEmpty
                ? 'Defina o path do servidor em Config > Arquivos.'
                : 'Caminho esperado: ${p.join(_serverPath, 'server.properties')}',
          ),
          const SizedBox(height: 14),
          _sectionTitle('Servidor'),
          _fieldLabel('Nome do servidor'),
          AppTextInput(
            controller: _serverNameController,
            hint: 'Ex.: Meu servidor',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          _fieldLabel('Descricao'),
          AppTextInput(
            controller: _descriptionController,
            hint: 'Ex.: Servidor survival vanilla',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          _fieldLabel('Seed'),
          AppTextInput(
            controller: _seedController,
            hint: 'Ex.: 123456789',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          AppSwitchCard(
            label: 'Hardcore',
            value: _hardcore,
            onChanged: (value) => setState(() => _hardcore = value),
          ),
          const SizedBox(height: 12),
          _fieldLabel('Modo de jogo'),
          AppSelect<String>(
            value: _gameMode,
            items: const [
              AppSelectItem(value: 'survival', label: 'Survival'),
              AppSelectItem(value: 'creative', label: 'Creative'),
              AppSelectItem(value: 'adventure', label: 'Adventure'),
              AppSelectItem(value: 'spectator', label: 'Spectator'),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _gameMode = value);
              }
            },
          ),
          const SizedBox(height: 12),
          _fieldLabel('Max players'),
          AppTextInput(
            controller: _maxPlayersController,
            hint: 'Ex.: 20',
            keyboardType: TextInputType.number,
            onChanged: (_) {
              _validateNumbers();
              setState(() {});
            },
          ),
          const SizedBox(height: 12),
          AppSwitchCard(
            label: 'PVP',
            value: _pvp,
            onChanged: (value) => setState(() => _pvp = value),
          ),
          const SizedBox(height: 12),
          AppSwitchCard(
            label: 'Whitelist',
            value: _whitelist,
            onChanged: (value) => setState(() => _whitelist = value),
          ),
          const SizedBox(height: 18),
          _sectionTitle('Distancias'),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('View distance'),
                    AppTextInput(
                      controller: _viewDistanceController,
                      hint: 'Ex.: 10',
                      keyboardType: TextInputType.number,
                      onChanged: (_) {
                        _validateNumbers();
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('Simulation distance'),
                    AppTextInput(
                      controller: _simulationDistanceController,
                      hint: 'Ex.: 10',
                      keyboardType: TextInputType.number,
                      onChanged: (_) {
                        _validateNumbers();
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_numbersError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _numbersError!,
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
                  onPressed: _cancel,
                  variant: AppVariant.danger,
                  transparent: true,
                  icon: Icons.close_rounded,
                ),
              if (_isDirty) const SizedBox(width: 10),
              AppButton(
                label: 'Salvar',
                onPressed: _save,
                isLoading: _isSaving,
                isDisabled: !_isDirty || !_canSave || _isSaving,
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
