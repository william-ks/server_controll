import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../components/buttons/app_button.dart';
import '../../../components/modal/app_modal.dart';
import '../../../components/shared/app_variant.dart';
import '../../../config/providers/theme_provider.dart';
import '../../../database/app_database.dart';
import '../providers/config_files_provider.dart';

class AdvancedSettingsTab extends ConsumerStatefulWidget {
  const AdvancedSettingsTab({super.key});

  @override
  ConsumerState<AdvancedSettingsTab> createState() => _AdvancedSettingsTabState();
}

class _AdvancedSettingsTabState extends ConsumerState<AdvancedSettingsTab> {
  bool _isClearing = false;

  Future<void> _clearAllData() async {
    final firstConfirm = await showDialog<bool>(
      context: context,
      builder: (_) => AppModal(
        icon: Icons.warning_amber_rounded,
        title: 'Confirmação necessária',
        width: 560,
        body: const Text(
          'Isso vai apagar todos os dados locais do MineControl (configurações, whitelist local e estado persistido). Deseja continuar?',
        ),
        actions: [
          AppButton(
            label: 'Cancelar',
            onPressed: () => Navigator.of(context).pop(false),
            type: AppButtonType.textButton,
            variant: AppVariant.danger,
          ),
          AppButton(
            label: 'Continuar',
            onPressed: () => Navigator.of(context).pop(true),
            variant: AppVariant.warning,
            icon: Icons.arrow_forward_rounded,
          ),
        ],
      ),
    );

    if (firstConfirm != true || !mounted) return;

    final secondConfirm = await showDialog<bool>(
      context: context,
      builder: (_) => AppModal(
        icon: Icons.delete_forever_rounded,
        title: 'Última confirmação',
        width: 560,
        body: const Text('A operação é irreversível. Confirmar limpeza total agora?'),
        actions: [
          AppButton(
            label: 'Voltar',
            onPressed: () => Navigator.of(context).pop(false),
            type: AppButtonType.textButton,
            variant: AppVariant.danger,
          ),
          AppButton(
            label: 'Limpar tudo',
            onPressed: () => Navigator.of(context).pop(true),
            variant: AppVariant.danger,
            icon: Icons.delete_forever_rounded,
          ),
        ],
      ),
    );

    if (secondConfirm != true || !mounted) return;

    setState(() => _isClearing = true);
    try {
      await AppDatabase.instance.resetDatabase();
      await AppDatabase.instance.database;

      final appDir = await getApplicationSupportDirectory();
      final iconsDir = Directory(p.join(appDir.path, 'whitelist_icons'));
      if (await iconsDir.exists()) {
        await iconsDir.delete(recursive: true);
      }

      await ref.read(configFilesProvider.notifier).loadFromDb();
      await ref.read(themeModeProvider.notifier).setMode(ThemeMode.dark);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dados locais limpos com sucesso.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isClearing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.error.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: scheme.error.withValues(alpha: 0.28)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 16, color: scheme.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Zona avançada: limpar dados remove todo o estado local da aplicação.',
                    style: TextStyle(color: scheme.error, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          AppButton(
            label: 'Limpar dados',
            onPressed: _isClearing ? null : _clearAllData,
            isLoading: _isClearing,
            isDisabled: _isClearing,
            variant: AppVariant.danger,
            icon: Icons.delete_sweep_rounded,
          ),
        ],
      ),
    );
  }
}
