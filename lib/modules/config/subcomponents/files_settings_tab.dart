import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../components/buttons/app_button.dart';
import '../../../components/inputs/app_switch_card.dart';
import '../../../components/inputs/app_text_input.dart';
import '../../../components/shared/app_variant.dart';
import '../../../config/theme/app_colors.dart';
import '../../../database/app_database.dart';

class FilesSettingsTab extends StatefulWidget {
  const FilesSettingsTab({super.key});

  @override
  State<FilesSettingsTab> createState() => _FilesSettingsTabState();
}

class _FilesSettingsTabState extends State<FilesSettingsTab> {
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
    _load();
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
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final db = AppDatabase.instance;

    final serverPath = await db.getSetting('server_dir') ?? '';
    final jarFile = await db.getSetting('jar_file') ?? 'server.jar';
    final javaCommand = await db.getSetting('java_command') ?? 'java';
    final jvmArgs = await db.getSetting('jvm_args') ?? '';
    final xms = await db.getSetting('xms') ?? '2G';
    final xmx = await db.getSetting('xmx') ?? '8G';
    final autoRestartRaw = await db.getSetting('auto_restart_on_crash') ?? '1';
    final restartWaitRaw = await db.getSetting('restart_wait_seconds') ?? '10';

    _serverPathController.text = serverPath;
    _jarFileController.text = jarFile;
    _javaCommandController.text = javaCommand;
    _jvmArgsController.text = jvmArgs;
    _ramMinController.text = _extractGb(xms, fallback: '2');
    _ramMaxController.text = _extractGb(xmx, fallback: '8');
    _autoRestartOnCrash = autoRestartRaw != '0';
    _restartWaitController.text = restartWaitRaw;

    await _validatePath();
    await _validateFile();
    _validateRam();
    _validateRestartWait();

    _initialSnapshot = _snapshot();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _validatePath() async {
    final path = _serverPathController.text.trim();
    if (path.isEmpty) {
      setState(() => _pathExists = false);
      return;
    }
    final exists = await Directory(path).exists();
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
    final exists = await File(p.join(serverPath, fileName)).exists();
    if (mounted) {
      setState(() => _fileExists = exists);
    }
  }

  void _onPathChanged() {
    _pathDebounce?.cancel();
    _pathDebounce = Timer(const Duration(milliseconds: 320), () async {
      await _validatePath();
      await _validateFile();
      if (mounted) setState(() {});
    });
  }

  void _onJarChanged() {
    _fileDebounce?.cancel();
    _fileDebounce = Timer(const Duration(milliseconds: 320), () async {
      await _validateFile();
      if (mounted) setState(() {});
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
    final wait = int.tryParse(_restartWaitController.text.trim());
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

  String _extractGb(String value, {required String fallback}) {
    final normalized = value.trim().toUpperCase();
    if (normalized.endsWith('G')) {
      return normalized.substring(0, normalized.length - 1);
    }
    return normalized.isEmpty ? fallback : normalized;
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

  bool get _isValidForSave {
    final hasPath = _serverPathController.text.trim().isNotEmpty;
    final hasFileName = _jarFileController.text.trim().isNotEmpty;
    final hasJavaCommand = _javaCommandController.text.trim().isNotEmpty;
    return hasPath &&
        hasFileName &&
        hasJavaCommand &&
        _pathExists &&
        _fileExists &&
        _ramError == null &&
        (_autoRestartOnCrash ? _restartError == null : true);
  }

  Future<void> _save() async {
    if (!_isValidForSave) {
      return;
    }
    setState(() => _isSaving = true);
    try {
      final db = AppDatabase.instance;
      await db.setSetting('server_dir', _serverPathController.text.trim());
      await db.setSetting('jar_file', _jarFileController.text.trim());
      await db.setSetting('java_command', _javaCommandController.text.trim());
      await db.setSetting('jvm_args', _jvmArgsController.text.trim());
      await db.setSetting('xms', '${_ramMinController.text.trim()}G');
      await db.setSetting('xmx', '${_ramMaxController.text.trim()}G');
      await db.setSetting('auto_restart_on_crash', _autoRestartOnCrash ? '1' : '0');
      await db.setSetting('restart_wait_seconds', _restartWaitController.text.trim());
      _initialSnapshot = _snapshot();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuracoes salvas com sucesso.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _cancelChanges() async {
    await _load();
  }

  Widget _sectionTitle(String text, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
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
          _sectionTitle('Core', color: Theme.of(context).colorScheme.secondary),
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
          _sectionTitle('Memoria RAM'),
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
                isDisabled: !_isDirty || !_isValidForSave || _isSaving,
                variant: AppVariant.success,
                icon: Icons.save_rounded,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!_isValidForSave && _isDirty)
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Revise os campos obrigatorios e validacoes antes de salvar.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.warning),
              ),
            ),
        ],
      ),
    );
  }
}
