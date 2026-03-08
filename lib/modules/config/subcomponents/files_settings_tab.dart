import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../components/badges/app_badge.dart';
import '../../../components/buttons/app_button.dart';
import '../../../components/inputs/app_switch_card.dart';
import '../../../components/inputs/app_text_input.dart';
import '../../../components/shared/app_variant.dart';
import '../models/config_files_settings.dart';
import '../providers/config_files_provider.dart';
import 'sticky_form_actions_bar.dart';

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
  final TextEditingController _maintenanceIconPathController =
      TextEditingController();

  Timer? _pathDebounce;
  Timer? _fileDebounce;
  Timer? _javaDebounce;

  bool _pathExists = false;
  bool _fileExists = false;
  bool? _javaAvailable;
  bool _checkingJava = false;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _autoRestartOnCrash = true;
  bool _maintenanceIconPathExists = false;
  String? _ramError;
  String? _restartError;
  String? _initialSnapshot;

  @override
  void initState() {
    super.initState();
    _serverPathController.addListener(_onPathChanged);
    _jarFileController.addListener(_onJarChanged);
    _javaCommandController.addListener(_onJavaCommandChanged);
    _ramMinController.addListener(_onRamChanged);
    _ramMaxController.addListener(_onRamChanged);
    _restartWaitController.addListener(_onRestartWaitChanged);
    _maintenanceIconPathController.addListener(_onMaintenanceIconPathChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFromProvider(refresh: true);
    });
  }

  @override
  void dispose() {
    _pathDebounce?.cancel();
    _fileDebounce?.cancel();
    _javaDebounce?.cancel();
    _serverPathController.dispose();
    _ramMinController.dispose();
    _ramMaxController.dispose();
    _jarFileController.dispose();
    _javaCommandController.dispose();
    _jvmArgsController.dispose();
    _restartWaitController.dispose();
    _maintenanceIconPathController.dispose();
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
    await _validateJavaCommand();
    _validateRam();
    _validateRestartWait();
    await _validateMaintenanceIconPath();
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
    _maintenanceIconPathController.text = settings.maintenanceIconPath;
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

  Future<void> _validateJavaCommand() async {
    final javaCommand = _javaCommandController.text.trim();
    if (javaCommand.isEmpty) {
      if (mounted) {
        setState(() {
          _javaAvailable = false;
          _checkingJava = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() => _checkingJava = true);
    }
    try {
      final result = await Process.run(javaCommand, const [
        '-version',
      ], runInShell: true).timeout(const Duration(seconds: 4));

      if (mounted) {
        setState(() {
          _javaAvailable = result.exitCode == 0;
          _checkingJava = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _javaAvailable = false;
          _checkingJava = false;
        });
      }
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

  void _onJavaCommandChanged() {
    _javaDebounce?.cancel();
    _javaDebounce = Timer(const Duration(milliseconds: 350), () async {
      await _validateJavaCommand();
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

  void _onMaintenanceIconPathChanged() {
    _pathDebounce?.cancel();
    _pathDebounce = Timer(const Duration(milliseconds: 320), () async {
      await _validateMaintenanceIconPath();
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _validateRam() {
    final min = int.tryParse(_ramMinController.text.trim());
    final max = int.tryParse(_ramMaxController.text.trim());
    if (_ramMinController.text.trim().isEmpty ||
        _ramMaxController.text.trim().isEmpty) {
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

  Future<void> _validateMaintenanceIconPath() async {
    final path = _maintenanceIconPathController.text.trim();
    if (path.isEmpty) {
      if (mounted) {
        setState(() => _maintenanceIconPathExists = false);
      } else {
        _maintenanceIconPathExists = false;
      }
      return;
    }

    final exists = await File(path).exists();
    if (mounted) {
      setState(() => _maintenanceIconPathExists = exists);
    }
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
      _maintenanceIconPathController.text.trim(),
    ].join('|');
  }

  bool get _isDirty =>
      _initialSnapshot != null && _snapshot() != _initialSnapshot;

  bool get _hasEssentialsFilled {
    return _serverPathController.text.trim().isNotEmpty &&
        _jarFileController.text.trim().isNotEmpty &&
        _javaCommandController.text.trim().isNotEmpty;
  }

  bool get _hasValidPreconditions {
    return _hasEssentialsFilled &&
        _pathExists &&
        _fileExists &&
        _javaAvailable == true &&
        _ramError == null &&
        (_maintenanceIconPathController.text.trim().isEmpty ||
            _maintenanceIconPathExists);
  }

  ConfigFilesSettings _toSettings() {
    final ramMin = _ramMinController.text.trim().isEmpty
        ? '2'
        : _ramMinController.text.trim();
    final ramMax = _ramMaxController.text.trim().isEmpty
        ? '8'
        : _ramMaxController.text.trim();
    final restartWait = _restartWaitController.text.trim().isEmpty
        ? '10'
        : _restartWaitController.text.trim();

    return ConfigFilesSettings(
      serverPath: _serverPathController.text.trim(),
      ramMinGb: ramMin,
      ramMaxGb: ramMax,
      fileServerName: _jarFileController.text.trim(),
      javaCommand: _javaCommandController.text.trim(),
      jvmArgs: _jvmArgsController.text.trim(),
      autoRestartOnCrash: _autoRestartOnCrash,
      restartWaitSeconds: restartWait,
      maintenanceIconPath: _maintenanceIconPathController.text.trim(),
    );
  }

  Future<void> _pickMaintenanceIconFile() async {
    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: 'Selecione imagem padrão de manutenção',
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
    );
    if (picked == null ||
        picked.files.isEmpty ||
        picked.files.single.path == null) {
      return;
    }
    final sourcePath = picked.files.single.path!;
    final sourceFile = File(sourcePath);
    if (!sourceFile.existsSync()) {
      return;
    }

    final appDir = await getApplicationSupportDirectory();
    final targetDir = Directory(p.join(appDir.path, 'maintenance_assets'));
    await targetDir.create(recursive: true);
    final extension = p.extension(sourcePath).toLowerCase();
    final safeExt = extension.isEmpty ? '.png' : extension;
    final targetPath = p.join(targetDir.path, 'maintenance_default$safeExt');
    await sourceFile.copy(targetPath);
    _maintenanceIconPathController.text = targetPath;
    await _validateMaintenanceIconPath();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _save() async {
    if (!_isDirty || !_hasValidPreconditions || _checkingJava) return;
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final showPathBadge = _serverPathController.text.trim().isNotEmpty;
    final showFileBadge =
        _serverPathController.text.trim().isNotEmpty &&
        _jarFileController.text.trim().isNotEmpty;
    final showJavaBadge = _javaCommandController.text.trim().isNotEmpty;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
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
                    variant: _pathExists
                        ? AppVariant.success
                        : AppVariant.danger,
                    icon: _pathExists
                        ? Icons.check_circle_outline_rounded
                        : Icons.close_rounded,
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
                    variant: _fileExists
                        ? AppVariant.success
                        : AppVariant.danger,
                    icon: _fileExists
                        ? Icons.check_circle_outline_rounded
                        : Icons.close_rounded,
                  ),
                const SizedBox(height: 14),
                _fieldLabel('Comando do Java:'),
                Text(
                  'Comando utilizado pelo sistema para executar o Java no terminal. Esse valor sera utilizado quando o servidor for iniciado.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                AppTextInput(
                  controller: _javaCommandController,
                  hint: 'Ex.: java ou /usr/bin/java',
                  prefixIcon: const Icon(Icons.terminal_rounded),
                  onChanged: (_) => setState(() {}),
                ),
                if (showJavaBadge)
                  _validationBadge(
                    text: _checkingJava
                        ? 'VALIDANDO...'
                        : (_javaAvailable == true
                              ? 'JAVA DISPONIVEL'
                              : 'JAVA NAO ENCONTRADO'),
                    variant: _checkingJava
                        ? AppVariant.info
                        : (_javaAvailable == true
                              ? AppVariant.success
                              : AppVariant.danger),
                    icon: _checkingJava
                        ? Icons.hourglass_top_rounded
                        : (_javaAvailable == true
                              ? Icons.check_circle_outline_rounded
                              : Icons.close_rounded),
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
                  text:
                      'ATENCAO: Flags com -XX:+AlwaysPreTouch pre-alocam toda a RAM. Deixe vazio para o comportamento padrao.',
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
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 22),
                _sectionTitle('Comportamento'),
                AppSwitchCard(
                  label: 'Auto restart em caso de crash:',
                  value: _autoRestartOnCrash,
                  onChanged: (value) =>
                      setState(() => _autoRestartOnCrash = value),
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
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 22),
                _sectionTitle('Manutenção'),
                _fieldLabel('Imagem padrão para modo manutenção:'),
                Row(
                  children: [
                    Expanded(
                      child: AppTextInput(
                        controller: _maintenanceIconPathController,
                        hint: r'Ex.: C:\icons\maintenance.png',
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 10),
                    AppButton(
                      label: 'Selecionar arquivo',
                      icon: Icons.upload_file_rounded,
                      variant: AppVariant.info,
                      onPressed: _pickMaintenanceIconFile,
                    ),
                  ],
                ),
                if (_maintenanceIconPathController.text.trim().isNotEmpty)
                  _validationBadge(
                    text: _maintenanceIconPathExists
                        ? 'ARQUIVO ENCONTRADO'
                        : 'ARQUIVO NÃO ENCONTRADO',
                    variant: _maintenanceIconPathExists
                        ? AppVariant.success
                        : AppVariant.danger,
                    icon: _maintenanceIconPathExists
                        ? Icons.check_circle_outline_rounded
                        : Icons.close_rounded,
                  ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        StickyFormActionsBar(
          onSave: _save,
          onCancel: _isDirty ? _cancelChanges : null,
          saveEnabled:
              _isDirty &&
              _hasValidPreconditions &&
              !_checkingJava &&
              !_isSaving,
          saveLoading: _isSaving,
          helperText: _isDirty && !_hasValidPreconditions
              ? 'Para salvar: preencha Path, File Server e Java; valide path/jar/java; mantenha RAM valida (min <= max); e use caminho de imagem válido quando informado.'
              : null,
        ),
      ],
    );
  }
}
