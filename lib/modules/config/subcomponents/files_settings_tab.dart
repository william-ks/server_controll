import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../components/buttons/app_button.dart';
import '../../../components/inputs/app_switch_card.dart';
import '../../../components/inputs/app_text_input.dart';
import '../../../components/shared/app_variant.dart';
import '../../../config/theme/app_colors.dart';
import '../models/config_files_settings.dart';
import '../providers/config_files_provider.dart';

class FilesSettingsTab extends ConsumerStatefulWidget {
  const FilesSettingsTab({super.key});

  @override
  ConsumerState<FilesSettingsTab> createState() => _FilesSettingsTabState();
}

class _FilesSettingsTabState extends ConsumerState<FilesSettingsTab> {
  final TextEditingController _serverPathController = TextEditingController();
  final TextEditingController _ramMinController = TextEditingController();
  final TextEditingController _ramMaxController = TextEditingController();
  final TextEditingController _jarFileController = TextEditingController();
  final TextEditingController _javaCommandController = TextEditingController();
  final TextEditingController _jvmArgsController = TextEditingController();
  final TextEditingController _restartWaitController = TextEditingController();

  Timer? _pathDebounce;
  Timer? _fileDebounce;

  bool _pathExists = false;
  bool _fileExists = false;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _autoRestartOnCrash = true;
  String? _ramError;
  String? _restartError;
  String? _initialSnapshot;

  @override
  void initState() {
    super.initState();
    _serverPathController.addListener(_onPathChanged);
    _jarFileController.addListener(_onJarChanged);
    _ramMinController.addListener(_onRamChanged);
    _ramMaxController.addListener(_onRamChanged);
    _restartWaitController.addListener(_onRestartWaitChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFromProvider(refresh: true);
    });
  }

  @override
  void dispose() {
    _pathDebounce?.cancel();
    _fileDebounce?.cancel();
    _serverPathController.dispose();
    _ramMinController.dispose();
    _ramMaxController.dispose();
    _jarFileController.dispose();
    _javaCommandController.dispose();
    _jvmArgsController.dispose();
    _restartWaitController.dispose();

    unawaited(ref.read(configFilesProvider.notifier).refresh());
    super.dispose();
  }

  Future<void> _loadFromProvider({required bool refresh}) async {
    setState(() => _isLoading = true);
    final notifier = ref.read(configFilesProvider.notifier);
    if (refresh) {
      await notifier.refresh();
    }
    final settings = ref.read(configFilesProvider);
    _applySettings(settings);
    await _validatePath();
    await _validateFile();
    _validateRam();
    _validateRestartWait();
    _initialSnapshot = _snapshot();

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _applySettings(ConfigFilesSettings settings) {
    _serverPathController.text = settings.serverPath;
    _jarFileController.text = settings.fileServerName;
    _javaCommandController.text = settings.javaCommand;
    _jvmArgsController.text = settings.jvmArgs;
    _ramMinController.text = settings.ramMinGb;
    _ramMaxController.text = settings.ramMaxGb;
    _autoRestartOnCrash = settings.autoRestartOnCrash;
    _restartWaitController.text = settings.restartWaitSeconds;
  }

  Future<void> _validatePath() async {
    final serverPath = _serverPathController.text.trim();
    if (serverPath.isEmpty) {
      setState(() => _pathExists = false);
      return;
    }
    final exists = await Directory(serverPath).exists();
    if (mounted) {
      setState(() => _pathExists = exists);
    }
  }

  Future<void> _validateFile() async {
    final serverPath = _serverPathController.text.trim();
    final fileName = _jarFileController.text.trim();
    if (serverPath.isEmpty || fileName.isEmpty) {
      setState(() => _fileExists = false);
      return;
    }

    final filePath = p.join(serverPath, fileName);
    final exists = await File(filePath).exists();
    if (mounted) {
      setState(() => _fileExists = exists);
    }
  }

  void _onPathChanged() {
    _pathDebounce?.cancel();
    _pathDebounce = Timer(const Duration(milliseconds: 320), () async {
      await _validatePath();
      await _validateFile();
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _onJarChanged() {
    _fileDebounce?.cancel();
    _fileDebounce = Timer(const Duration(milliseconds: 320), () async {
      await _validateFile();
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _onRamChanged() {
    _validateRam();
    setState(() {});
  }

  void _onRestartWaitChanged() {
    _validateRestartWait();
    setState(() {});
  }

  void _validateRam() {
    final min = int.tryParse(_ramMinController.text.trim());
    final max = int.tryParse(_ramMaxController.text.trim());
    if (_ramMinController.text.trim().isEmpty || _ramMaxController.text.trim().isEmpty) {
      _ramError = null;
      return;
    }
    if (min == null || max == null) {
      _ramError = 'Informe valores numericos.';
      return;
    }
    if (min <= 0 || max <= 0) {
      _ramError = 'Os valores devem ser maiores que zero.';
      return;
    }
    if (min > max) {
      _ramError = 'O minimo nao pode ser maior que o maximo.';
      return;
    }
    _ramError = null;
  }

  void _validateRestartWait() {
    final waitRaw = _restartWaitController.text.trim();
    if (!_autoRestartOnCrash || waitRaw.isEmpty) {
      _restartError = null;
      return;
    }
    final wait = int.tryParse(waitRaw);
    if (wait == null) {
      _restartError = 'Informe um valor numerico.';
      return;
    }
    if (wait < 0) {
      _restartError = 'O tempo deve ser maior ou igual a zero.';
      return;
    }
    _restartError = null;
  }

  String _snapshot() {
    return [
      _serverPathController.text.trim(),
      _ramMinController.text.trim(),
      _ramMaxController.text.trim(),
      _jarFileController.text.trim(),
      _javaCommandController.text.trim(),
      _jvmArgsController.text.trim(),
      _autoRestartOnCrash ? '1' : '0',
      _restartWaitController.text.trim(),
    ].join('|');
  }

  bool get _isDirty => _initialSnapshot != null && _snapshot() != _initialSnapshot;

  ConfigFilesSettings _toSettings() {
    final ramMin = _ramMinController.text.trim().isEmpty ? '2' : _ramMinController.text.trim();
    final ramMax = _ramMaxController.text.trim().isEmpty ? '8' : _ramMaxController.text.trim();
    final restartWait = _restartWaitController.text.trim().isEmpty ? '10' : _restartWaitController.text.trim();

    return ConfigFilesSettings(
      serverPath: _serverPathController.text.trim(),
      ramMinGb: ramMin,
      ramMaxGb: ramMax,
      fileServerName: _jarFileController.text.trim(),
      javaCommand: _javaCommandController.text.trim(),
      jvmArgs: _jvmArgsController.text.trim(),
      autoRestartOnCrash: _autoRestartOnCrash,
      restartWaitSeconds: restartWait,
    );
  }

  Future<void> _save() async {
    if (!_isDirty) return;
    setState(() => _isSaving = true);
    try {
      final settings = _toSettings();
      await ref.read(configFilesProvider.notifier).saveToDb(settings);
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
        style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w400),
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
            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
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

    final showPathBadge = _serverPathController.text.trim().isNotEmpty;
    final showFileBadge = _serverPathController.text.trim().isNotEmpty && _jarFileController.text.trim().isNotEmpty;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Core'),
          _fieldLabel('Path do servidor:'),
          AppTextInput(
            controller: _serverPathController,
            hint: r'Ex.: C:\minecraft\meu-servidor',
            prefixIcon: const Icon(Icons.folder_open_rounded),
            onChanged: (_) => setState(() {}),
          ),
          if (showPathBadge)
            _validationBadge(
              text: _pathExists ? 'ENCONTRADO' : 'NAO ENCONTRADO',
              variant: _pathExists ? AppVariant.success : AppVariant.danger,
              icon: _pathExists ? Icons.check_circle_outline_rounded : Icons.close_rounded,
            ),
          if (!showPathBadge)
            _validationBadge(
              text: 'INFORME O PATH',
              variant: AppVariant.info,
              icon: Icons.info_outline_rounded,
            ),
          const SizedBox(height: 14),
          _fieldLabel('Nome do file server:'),
          AppTextInput(
            controller: _jarFileController,
            hint: 'Ex.: server.jar',
            prefixIcon: const Icon(Icons.insert_drive_file_outlined),
            onChanged: (_) => setState(() {}),
          ),
          if (showFileBadge)
            _validationBadge(
              text: _fileExists ? 'ENCONTRADO' : 'NAO ENCONTRADO',
              variant: _fileExists ? AppVariant.success : AppVariant.danger,
              icon: _fileExists ? Icons.check_circle_outline_rounded : Icons.close_rounded,
            ),
          const SizedBox(height: 14),
          _fieldLabel('Comando do Java:'),
          Text(
            'Comando utilizado pelo sistema para executar o Java no terminal. Esse valor sera utilizado quando o servidor for iniciado.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          AppTextInput(
            controller: _javaCommandController,
            hint: 'Ex.: java ou /usr/bin/java',
            prefixIcon: const Icon(Icons.terminal_rounded),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          _fieldLabel('JVM args:'),
          AppTextInput(
            controller: _jvmArgsController,
            hint: 'Ex.: -Xms2G',
            prefixIcon: const Icon(Icons.tune_rounded),
            onChanged: (_) => setState(() {}),
          ),
          _validationBadge(
            text: 'ATENCAO: Flags com -XX:+AlwaysPreTouch pre-alocam toda a RAM. Deixe vazio para o comportamento padrao.',
            variant: AppVariant.warning,
            icon: Icons.warning_amber_rounded,
          ),
          const SizedBox(height: 22),
          _sectionTitle('Memória RAM'),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('Minimo (GB):'),
                    AppTextInput(
                      controller: _ramMinController,
                      hint: 'Ex.: 2',
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('Maximo (GB):'),
                    AppTextInput(
                      controller: _ramMaxController,
                      hint: 'Ex.: 8',
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_ramError != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _ramError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 22),
          _sectionTitle('Comportamento'),
          AppSwitchCard(
            label: 'Auto restart em caso de crash:',
            value: _autoRestartOnCrash,
            onChanged: (value) => setState(() => _autoRestartOnCrash = value),
          ),
          const SizedBox(height: 10),
          _fieldLabel('Tempo de espera para restart (segundos):'),
          AppTextInput(
            controller: _restartWaitController,
            enabled: _autoRestartOnCrash,
            hint: 'Ex.: 10',
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
          ),
          if (_autoRestartOnCrash && _restartError != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _restartError!,
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
                isDisabled: !_isDirty || _isSaving,
                variant: AppVariant.success,
                icon: Icons.save_rounded,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if ((_ramError != null || _restartError != null) && _isDirty)
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Existem avisos de validacao, mas o salvamento continua permitido.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.warning),
              ),
            ),
        ],
      ),
    );
  }
}
