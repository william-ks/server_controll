import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../components/buttons/app_button.dart';
import '../../../../components/modal/app_modal.dart';
import '../../../../components/shared/app_variant.dart';
import '../../backup/providers/backups_provider.dart';
import '../../backup/services/backup_service.dart';

enum ManualBackupResultType { success, cancelled, error }

class ManualBackupResult {
  const ManualBackupResult({required this.type, this.message});

  final ManualBackupResultType type;
  final String? message;
}

class ManualBackupConfirmModal extends StatelessWidget {
  const ManualBackupConfirmModal({super.key});

  @override
  Widget build(BuildContext context) {
    return AppModal(
      icon: Icons.backup_rounded,
      title: 'Backup manual',
      body: const Text(
        'O backup manual será salvo como Manual_<timestamp>.zip. O servidor precisa estar OFFLINE para continuar.',
      ),
      actions: [
        AppButton(
          label: 'Cancelar',
          type: AppButtonType.textButton,
          variant: AppVariant.danger,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton(
          label: 'Confirmar',
          variant: AppVariant.success,
          icon: Icons.check_rounded,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}

class ManualBackupProgressModal extends ConsumerStatefulWidget {
  const ManualBackupProgressModal({super.key, required this.controller});

  final BackupTaskController controller;

  @override
  ConsumerState<ManualBackupProgressModal> createState() =>
      _ManualBackupProgressModalState();
}

class _ManualBackupProgressModalState
    extends ConsumerState<ManualBackupProgressModal> {
  static const _messages = [
    'Eliminando seus creepers...',
    'Me escondendo dos Endermens...',
    'Matando um esqueleto...',
    'Lendo os arquivos...',
    'Salvando...',
    'Compactando...',
    'Transferindo...',
    'Fugindo do Herobrine...',
    'Deletando o arquivo do Herobrine...',
    'Voltando para o Overworld...',
  ];

  Timer? _messageTimer;
  int _messageIndex = 0;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    _messageTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      setState(() {
        _messageIndex = (_messageIndex + 1) % _messages.length;
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runBackup();
    });
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    super.dispose();
  }

  Future<void> _runBackup() async {
    try {
      await ref
          .read(backupsProvider.notifier)
          .createManualBackupWithController(widget.controller);
      if (!mounted) return;
      Navigator.of(context).pop(
        const ManualBackupResult(
          type: ManualBackupResultType.success,
          message: 'Backup manual concluído com sucesso.',
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final msg = error.toString().replaceFirst('Bad state: ', '');
      Navigator.of(context).pop(
        ManualBackupResult(
          type: msg.contains('cancelado')
              ? ManualBackupResultType.cancelled
              : ManualBackupResultType.error,
          message: msg,
        ),
      );
    }
  }

  Future<void> _cancelBackup() async {
    if (_cancelling) return;
    setState(() => _cancelling = true);
    await widget.controller.cancel();
    if (!mounted) return;
    Navigator.of(context).pop(
      const ManualBackupResult(
        type: ManualBackupResultType.cancelled,
        message: 'Cancelamento solicitado. O backup parcial será removido.',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppModal(
      icon: Icons.sync_rounded,
      title: _cancelling ? 'Cancelando backup...' : 'Executando backup manual',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 14),
          Text(
            _messages[_messageIndex],
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
      actions: [
        AppButton(
          label: 'Cancelar',
          type: AppButtonType.textButton,
          variant: AppVariant.danger,
          onPressed: _cancelling ? null : _cancelBackup,
          isDisabled: _cancelling,
        ),
      ],
    );
  }
}
