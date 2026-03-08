import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../components/badges/app_badge.dart';
import '../../../components/buttons/app_button.dart';
import '../../../components/inputs/app_switch_card.dart';
import '../../../components/inputs/app_text_input.dart';
import '../../../components/selects/app_select.dart';
import '../../../components/shared/app_variant.dart';
import '../../backup/subcomponents/selective_backup_modal.dart';
import '../../config/providers/config_files_provider.dart';
import '../models/chunky_backup_kind.dart';
import '../models/chunky_config_settings.dart';
import '../models/chunky_execution_status.dart';
import '../providers/chunky_config_provider.dart';
import '../providers/chunky_execution_provider.dart';

class ChunkyConfigTab extends ConsumerStatefulWidget {
  const ChunkyConfigTab({super.key});

  @override
  ConsumerState<ChunkyConfigTab> createState() => _ChunkyConfigTabState();
}

class _ChunkyConfigTabState extends ConsumerState<ChunkyConfigTab> {
  final TextEditingController _chunkPathController = TextEditingController();
  final TextEditingController _centerXController = TextEditingController();
  final TextEditingController _centerZController = TextEditingController();
  final TextEditingController _radiusController = TextEditingController();
  final TextEditingController _maxChunksController = TextEditingController();

  final FocusNode _centerXFocus = FocusNode();
  final FocusNode _centerZFocus = FocusNode();
  final FocusNode _radiusFocus = FocusNode();
  final FocusNode _maxChunksFocus = FocusNode();

  String _pattern = 'spiral';
  String _shape = 'square';
  bool _backupBeforeStart = false;
  ChunkyBackupKind _backupKind = ChunkyBackupKind.world;
  List<String> _backupSelectiveRoots = const [];
  bool _isLoading = true;
  bool _isSaving = false;
  Timer? _saveDebounce;

  @override
  void initState() {
    super.initState();
    _centerXFocus.addListener(() => _saveOnBlur(_centerXFocus));
    _centerZFocus.addListener(() => _saveOnBlur(_centerZFocus));
    _radiusFocus.addListener(() => _saveOnBlur(_radiusFocus));
    _maxChunksFocus.addListener(() => _saveOnBlur(_maxChunksFocus));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _chunkPathController.dispose();
    _centerXController.dispose();
    _centerZController.dispose();
    _radiusController.dispose();
    _maxChunksController.dispose();
    _centerXFocus.dispose();
    _centerZFocus.dispose();
    _radiusFocus.dispose();
    _maxChunksFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    await ref.read(chunkyConfigProvider.notifier).loadFromDb();
    final settings = ref.read(chunkyConfigProvider);
    _chunkPathController.text = '';
    _centerXController.text = settings.centerX;
    _centerZController.text = settings.centerZ;
    _radiusController.text = settings.radius;
    _maxChunksController.text = settings.maxChunksPerRun;
    _pattern = settings.pattern;
    _shape = settings.shape;
    _backupBeforeStart = settings.backupBeforeStart;
    _backupKind = settings.backupKind;
    _backupSelectiveRoots = [...settings.backupSelectiveRoots]..sort();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _saveOnBlur(FocusNode focusNode) {
    if (!focusNode.hasFocus) {
      _saveDebounce?.cancel();
      _saveDebounce = Timer(const Duration(milliseconds: 120), _save);
    }
  }

  Future<void> _save() async {
    if (_isSaving || _isLoading) return;
    final execution = ref.read(chunkyExecutionProvider);
    final locked =
        execution.tasksPending ||
        execution.status == ChunkyExecutionStatus.running ||
        execution.status == ChunkyExecutionStatus.paused ||
        execution.status == ChunkyExecutionStatus.cancelling;
    if (locked) return;
    setState(() => _isSaving = true);
    try {
      final settings = ChunkyConfigSettings(
        centerX: _centerXController.text.trim().isEmpty
            ? '0'
            : _centerXController.text.trim(),
        centerZ: _centerZController.text.trim().isEmpty
            ? '0'
            : _centerZController.text.trim(),
        radius: _radiusController.text.trim().isEmpty
            ? '1000'
            : _radiusController.text.trim(),
        pattern: _pattern,
        shape: _shape,
        maxChunksPerRun: _maxChunksController.text.trim().isEmpty
            ? '1000'
            : _maxChunksController.text.trim(),
        backupBeforeStart: _backupBeforeStart,
        backupKind: _backupKind,
        backupSelectiveRoots: _backupSelectiveRoots,
        radiusMode: ref.read(chunkyConfigProvider).radiusMode,
      );
      await ref.read(chunkyConfigProvider.notifier).save(settings);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
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
    final serverPath = ref.watch(configFilesProvider).serverPath.trim();
    final execution = ref.watch(chunkyExecutionProvider);
    final configLocked =
        execution.hasRecoverableCheckpoint ||
        execution.status == ChunkyExecutionStatus.awaitingResume ||
        execution.tasksPending ||
        execution.status == ChunkyExecutionStatus.running ||
        execution.status == ChunkyExecutionStatus.paused ||
        execution.status == ChunkyExecutionStatus.cancelling;
    final chunkFolderPath = serverPath.isEmpty
        ? ''
        : p.join(serverPath, 'config', 'Chunky');
    _chunkPathController.text = chunkFolderPath;
    final maxChunks = int.tryParse(_maxChunksController.text.trim()) ?? 1000;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (configLocked) ...[
            const AppBadge(
              icon: Icons.lock_rounded,
              variant: AppVariant.warning,
              title:
                  'Config bloqueada enquanto houver tarefa pendente/execução.',
            ),
            const SizedBox(height: 12),
          ],
          _fieldLabel('Pasta do Chunk'),
          if (serverPath.isEmpty)
            const AppBadge(
              icon: Icons.info_outline_rounded,
              variant: AppVariant.info,
              title: 'Defina o Path do servidor em Config > Arquivos.',
            )
          else
            AppTextInput(controller: _chunkPathController, enabled: false),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('Center X'),
                    AppTextInput(
                      controller: _centerXController,
                      focusNode: _centerXFocus,
                      hint: 'Ex.: 0',
                      enabled: !configLocked,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('Center Z'),
                    AppTextInput(
                      controller: _centerZController,
                      focusNode: _centerZFocus,
                      hint: 'Ex.: 0',
                      enabled: !configLocked,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _fieldLabel('Radius'),
          AppTextInput(
            controller: _radiusController,
            focusNode: _radiusFocus,
            hint: 'Ex.: 1000',
            keyboardType: TextInputType.number,
            enabled: !configLocked,
          ),
          const SizedBox(height: 14),
          _fieldLabel('Pattern'),
          AppSelect<String>(
            value: _pattern,
            items: const [
              AppSelectItem(value: 'spiral', label: 'Spiral'),
              AppSelectItem(value: 'loop', label: 'Loop'),
              AppSelectItem(value: 'concentric', label: 'Concentric'),
              AppSelectItem(value: 'region', label: 'Region'),
              AppSelectItem(value: 'csv', label: 'CSV'),
              AppSelectItem(value: 'world', label: 'World'),
            ],
            enabled: !configLocked,
            onChanged: (value) async {
              if (value == null) return;
              setState(() => _pattern = value);
              await _save();
            },
          ),
          const SizedBox(height: 14),
          _fieldLabel('Shape'),
          AppSelect<String>(
            value: _shape,
            items: const [
              AppSelectItem(value: 'square', label: 'Square'),
              AppSelectItem(value: 'circle', label: 'Circle'),
              AppSelectItem(value: 'triangle', label: 'Triangle'),
              AppSelectItem(value: 'diamond', label: 'Diamond'),
              AppSelectItem(value: 'pentagon', label: 'Pentagon'),
              AppSelectItem(value: 'hexagon', label: 'Hexagon'),
              AppSelectItem(value: 'star', label: 'Star'),
              AppSelectItem(value: 'rectangle', label: 'Rectangle'),
              AppSelectItem(value: 'ellipse', label: 'Ellipse'),
            ],
            enabled: !configLocked,
            onChanged: (value) async {
              if (value == null) return;
              setState(() => _shape = value);
              await _save();
            },
          ),
          const SizedBox(height: 14),
          _fieldLabel('Máximo de chunks gerados por vez'),
          AppTextInput(
            controller: _maxChunksController,
            focusNode: _maxChunksFocus,
            hint: 'Ex.: 1000',
            keyboardType: TextInputType.number,
            enabled: !configLocked,
          ),
          if (maxChunks > 5000) ...[
            const SizedBox(height: 8),
            const AppBadge(
              icon: Icons.warning_amber_rounded,
              variant: AppVariant.warning,
              title: 'Opa, esse valor não é recomendado por ser muito alto.',
            ),
          ],
          if (_isSaving) ...[
            const SizedBox(height: 8),
            Text(
              'Salvando...',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
          const SizedBox(height: 18),
          _fieldLabel('Backup antes de iniciar Chunky'),
          AppSwitchCard(
            label: 'Executar backup antes do primeiro run',
            value: _backupBeforeStart,
            onChanged: configLocked
                ? null
                : (value) async {
                    setState(() => _backupBeforeStart = value);
                    await _save();
                  },
          ),
          if (_backupBeforeStart) ...[
            const SizedBox(height: 12),
            _fieldLabel('Tipo de backup'),
            AppSelect<ChunkyBackupKind>(
              value: _backupKind,
              items: const [
                AppSelectItem(
                  value: ChunkyBackupKind.full,
                  label: 'Servidor (total)',
                ),
                AppSelectItem(value: ChunkyBackupKind.world, label: 'Mundo'),
                AppSelectItem(
                  value: ChunkyBackupKind.selective,
                  label: 'Seletivo',
                ),
              ],
              enabled: !configLocked,
              onChanged: (value) async {
                if (value == null) return;
                setState(() {
                  _backupKind = value;
                  if (_backupKind != ChunkyBackupKind.selective) {
                    _backupSelectiveRoots = const [];
                  }
                });
                await _save();
              },
            ),
            if (_backupKind == ChunkyBackupKind.selective) ...[
              const SizedBox(height: 10),
              AppButton(
                label: 'Escolher itens',
                icon: Icons.playlist_add_check_rounded,
                variant: AppVariant.info,
                transparent: true,
                isDisabled: configLocked,
                onPressed: configLocked
                    ? null
                    : () async {
                        await showDialog<bool>(
                          context: context,
                          builder: (_) => SelectiveBackupModal(
                            onConfirm: (selectedRoots) async {
                              setState(() {
                                _backupSelectiveRoots = [...selectedRoots]
                                  ..sort();
                              });
                              await _save();
                            },
                          ),
                        );
                      },
              ),
              const SizedBox(height: 6),
              Text(
                _backupSelectiveRoots.isEmpty
                    ? 'Nenhum item selecionado.'
                    : _backupSelectiveRoots.join(', '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ],
      ),
    );
  }
}
