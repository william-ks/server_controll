import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../components/buttons/app_button.dart';
import '../../../components/modal/app_modal.dart';
import '../../../components/shared/app_variant.dart';
import '../../config/providers/config_files_provider.dart';

class SelectiveBackupModal extends ConsumerStatefulWidget {
  const SelectiveBackupModal({super.key, required this.onConfirm});

  final Future<void> Function(List<String> selectedRoots) onConfirm;

  @override
  ConsumerState<SelectiveBackupModal> createState() =>
      _SelectiveBackupModalState();
}

class _SelectiveBackupModalState extends ConsumerState<SelectiveBackupModal> {
  final Set<String> _selected = <String>{};
  List<_RootEntry> _entries = const [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadEntries();
    });
  }

  Future<void> _loadEntries() async {
    setState(() {
      _loading = true;
      _error = null;
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
        final name = p.basename(entity.path);
        if (name.isEmpty) continue;
        entries.add(_RootEntry(name: name, isDirectory: entity is Directory));
      }
      entries.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  Future<void> _confirm() async {
    if (_selected.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await widget.onConfirm(_selected.toList()..sort());
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
      icon: Icons.library_add_check_rounded,
      title: 'Backup seletivo',
      width: 760,
      maxBodyHeight: 520,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selecione arquivos e pastas do primeiro nível da raiz do servidor.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Pastas selecionadas serão incluídas recursivamente. Não é permitido escolher subarquivos individualmente.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            )
          else if (_entries.isEmpty)
            const Text('Nenhum item encontrado na raiz do servidor.')
          else
            SizedBox(
              height: 260,
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
                    final checked = _selected.contains(item.name);
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
                          if (value ?? false) {
                            _selected.add(item.name);
                          } else {
                            _selected.remove(item.name);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
            ),
          const SizedBox(height: 10),
          Text(
            'Itens incluídos: ${_selected.isEmpty ? 'nenhum' : (_selected.toList()..sort()).join(', ')}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
      actions: [
        AppButton(
          label: 'Cancelar',
          onPressed: () => Navigator.of(context).pop(false),
          type: AppButtonType.textButton,
          variant: AppVariant.danger,
        ),
        AppButton(
          label: 'Criar backup seletivo',
          onPressed: _confirm,
          isLoading: _saving,
          isDisabled: _selected.isEmpty || _saving,
          variant: AppVariant.success,
          icon: Icons.archive_rounded,
        ),
      ],
    );
  }
}

class _RootEntry {
  const _RootEntry({required this.name, required this.isDirectory});

  final String name;
  final bool isDirectory;
}
