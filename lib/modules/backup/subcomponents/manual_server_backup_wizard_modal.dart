import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/buttons/app_button.dart';
import '../../../components/modal/app_modal.dart';
import '../../../components/selects/app_select.dart';
import '../../../components/shared/app_variant.dart';
import '../models/backup_entry.dart';
import 'manual_server_backup_flow.dart';
import 'selective_backup_modal.dart';

enum ManualServerBackupKind { fullServer, worldOnly, selective }

class ManualServerBackupWizardModal extends ConsumerStatefulWidget {
  const ManualServerBackupWizardModal({super.key});

  @override
  ConsumerState<ManualServerBackupWizardModal> createState() =>
      _ManualServerBackupWizardModalState();
}

class _ManualServerBackupWizardModalState
    extends ConsumerState<ManualServerBackupWizardModal> {
  int _step = 1;
  String? _error;

  ManualServerBackupKind _kind = ManualServerBackupKind.fullServer;
  List<String> _selectedRoots = const [];

  Future<void> _goToStep2() async {
    setState(() {
      _error = null;
      _step = 2;
    });
  }

  Future<void> _submit() async {
    if (_kind == ManualServerBackupKind.selective && _selectedRoots.isEmpty) {
      setState(() => _error = 'Selecione ao menos um item da raiz.');
      return;
    }
    Navigator.of(context).pop(
      ManualBackupRequest(
        kind: switch (_kind) {
          ManualServerBackupKind.fullServer => BackupContentKind.full,
          ManualServerBackupKind.worldOnly => BackupContentKind.world,
          ManualServerBackupKind.selective => BackupContentKind.selective,
        },
        selectiveRootEntries: _selectedRoots.toList()..sort(),
      ),
    );
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

  Future<void> _pickSelectiveEntries() async {
    await showDialog<bool>(
      context: context,
      builder: (_) => SelectiveBackupModal(
        onConfirm: (selectedRoots) async {
          setState(() {
            _selectedRoots = [...selectedRoots]..sort();
            _error = null;
          });
        },
      ),
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
          const Text('Selecione arquivos e pastas de primeiro nível da raiz do servidor.'),
          const SizedBox(height: 10),
          AppButton(
            label: 'Escolher itens',
            icon: Icons.playlist_add_check_rounded,
            variant: AppVariant.info,
            transparent: true,
            onPressed: _pickSelectiveEntries,
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
        onPressed: () => Navigator.of(context).pop(),
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
        onPressed: () {
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
        variant: AppVariant.success,
        icon: Icons.archive_rounded,
      ),
    ];
  }
}
