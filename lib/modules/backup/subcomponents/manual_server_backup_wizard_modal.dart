import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../components/buttons/app_button.dart';
import '../../../components/modal/app_modal.dart';
import '../../../components/selects/app_select.dart';
import '../../../components/shared/app_variant.dart';
import '../../config/providers/config_files_provider.dart';
import '../models/backup_entry.dart';

enum ManualServerBackupKind { fullServer, worldOnly, selective }

class ManualServerBackupWizardModal extends ConsumerStatefulWidget {
  const ManualServerBackupWizardModal({super.key, required this.onConfirm});

  final Future<void> Function({
    required BackupContentKind kind,
    required List<String> selectiveRootEntries,
  })
  onConfirm;

  @override
  ConsumerState<ManualServerBackupWizardModal> createState() =>
      _ManualServerBackupWizardModalState();
}

class _ManualServerBackupWizardModalState
    extends ConsumerState<ManualServerBackupWizardModal> {
  int _step = 1;
  bool _saving = false;
  bool _loadingEntries = false;
  String? _error;

  ManualServerBackupKind _kind = ManualServerBackupKind.fullServer;
  final Set<String> _selectedRoots = <String>{};
  List<_RootEntry> _entries = const [];

  Future<void> _goToStep2() async {
    setState(() {
      _error = null;
      _step = 2;
    });
    if (_kind == ManualServerBackupKind.selective) {
      await _loadEntries();
    }
  }

  Future<void> _loadEntries() async {
    setState(() {
      _loadingEntries = true;
      _error = null;
      _entries = const [];
      _selectedRoots.clear();
    });
    try {
      final serverPath = ref.read(configFilesProvider).serverPath.trim();
      if (serverPath.isEmpty) {
        throw StateError('Defina o path do servidor em Config > Arquivos.');
      }
      final serverDir = Directory(serverPath);
      if (!await serverDir.exists()) {
        throw StateError('Pasta do servidor não encontrada.');
      }

      final entries = <_RootEntry>[];
      await for (final entity in serverDir.list(
        recursive: false,
        followLinks: false,
      )) {
        final name = p.basename(entity.path).trim();
        if (name.isEmpty) continue;
        entries.add(_RootEntry(name: name, isDirectory: entity is Directory));
      }
      entries.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loadingEntries = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingEntries = false;
        _error = error.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (_kind == ManualServerBackupKind.selective && _selectedRoots.isEmpty) {
      setState(() => _error = 'Selecione ao menos um item da raiz.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onConfirm(
        kind: switch (_kind) {
          ManualServerBackupKind.fullServer => BackupContentKind.full,
          ManualServerBackupKind.worldOnly => BackupContentKind.world,
          ManualServerBackupKind.selective => BackupContentKind.selective,
        },
        selectiveRootEntries: _selectedRoots.toList()..sort(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppModal(
      icon: Icons.backup_rounded,
      title: 'Novo backup',
      width: 760,
      maxBodyHeight: 520,
      body: _step == 1 ? _buildStep1(context) : _buildStep2(context),
      actions: _step == 1 ? _step1Actions() : _step2Actions(),
    );
  }

  Widget _buildStep1(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Passo 1 de 2: selecione o tipo de backup.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        AppSelect<ManualServerBackupKind>(
          value: _kind,
          items: const [
            AppSelectItem(
              value: ManualServerBackupKind.fullServer,
              label: 'Servidor (total)',
            ),
            AppSelectItem(
              value: ManualServerBackupKind.worldOnly,
              label: 'Mundo',
            ),
            AppSelectItem(
              value: ManualServerBackupKind.selective,
              label: 'Seletivo',
            ),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() => _kind = value);
          },
        ),
        const SizedBox(height: 12),
        Text(
          _kind == ManualServerBackupKind.fullServer
              ? 'Backup total compacta toda a raiz do servidor.'
              : (_kind == ManualServerBackupKind.worldOnly
                    ? 'Backup de mundo compacta apenas a pasta do mundo ativo.'
                    : 'Backup seletivo permite escolher itens da raiz no próximo passo.'),
        ),
      ],
    );
  }

  Widget _buildStep2(BuildContext context) {
    final isSelective = _kind == ManualServerBackupKind.selective;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Passo 2 de 2: ${isSelective ? 'configure os itens do backup seletivo' : 'confirme o backup total do servidor'}.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        if (!isSelective)
          const Text(
            'Confirme para iniciar o backup.',
          ),
        if (isSelective) ...[
          const Text(
            'Selecione arquivos e pastas de primeiro nível da raiz do servidor.',
          ),
          const SizedBox(height: 10),
          if (_loadingEntries)
            const Center(child: CircularProgressIndicator())
          else if (_entries.isEmpty)
            const Text('Nenhum item encontrado na raiz do servidor.')
          else
            SizedBox(
              height: 240,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: ListView.builder(
                  itemCount: _entries.length,
                  itemBuilder: (_, index) {
                    final item = _entries[index];
                    final checked = _selectedRoots.contains(item.name);
                    return CheckboxListTile(
                      value: checked,
                      title: Text(item.name),
                      subtitle: Text(item.isDirectory ? 'Pasta' : 'Arquivo'),
                      secondary: Icon(
                        item.isDirectory
                            ? Icons.folder_rounded
                            : Icons.insert_drive_file_rounded,
                      ),
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selectedRoots.add(item.name);
                          } else {
                            _selectedRoots.remove(item.name);
                          }
                          _error = null;
                        });
                      },
                    );
                  },
                ),
              ),
            ),
          const SizedBox(height: 10),
          Text(
            'Itens incluídos: ${_selectedRoots.isEmpty ? 'nenhum' : (_selectedRoots.toList()..sort()).join(', ')}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }

  List<Widget> _step1Actions() {
    return [
      AppButton(
        label: 'Cancelar',
        onPressed: () => Navigator.of(context).pop(false),
        type: AppButtonType.textButton,
        variant: AppVariant.danger,
      ),
      AppButton(
        label: 'Próximo',
        onPressed: _goToStep2,
        variant: AppVariant.primary,
        icon: Icons.arrow_forward_rounded,
      ),
    ];
  }

  List<Widget> _step2Actions() {
    return [
      AppButton(
        label: 'Voltar',
        onPressed: _saving
            ? null
            : () {
                setState(() {
                  _step = 1;
                  _error = null;
                });
              },
        type: AppButtonType.textButton,
        variant: AppVariant.info,
      ),
      AppButton(
        label: _kind == ManualServerBackupKind.selective
            ? 'Criar backup seletivo'
            : (_kind == ManualServerBackupKind.worldOnly
                  ? 'Criar backup de mundo'
                  : 'Criar backup do servidor'),
        onPressed: _submit,
        isLoading: _saving,
        isDisabled: _saving || (_loadingEntries && _kind != ManualServerBackupKind.fullServer),
        variant: AppVariant.success,
        icon: Icons.archive_rounded,
      ),
    ];
  }
}

class _RootEntry {
  const _RootEntry({required this.name, required this.isDirectory});

  final String name;
  final bool isDirectory;
}
