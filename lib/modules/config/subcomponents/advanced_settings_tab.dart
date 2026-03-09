import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../components/badges/app_badge.dart';
import '../../../components/buttons/app_button.dart';
import '../../../components/modal/app_confirm_dialog.dart';
import '../../../components/shared/app_variant.dart';
import '../../../config/providers/theme_provider.dart';
import '../../../config/theme/app_theme_extension.dart';
import '../../../database/app_database.dart';
import '../providers/config_files_provider.dart';

class AdvancedSettingsTab extends ConsumerStatefulWidget {
  const AdvancedSettingsTab({super.key});

  @override
  ConsumerState<AdvancedSettingsTab> createState() =>
      _AdvancedSettingsTabState();
}

class _AdvancedSettingsTabState extends ConsumerState<AdvancedSettingsTab> {
  bool _isClearing = false;

  Future<void> _clearAllData() async {
    final firstConfirm = await showAppConfirmDialog(
      context,
      icon: Icons.warning_amber_rounded,
      title: 'Confirmação necessária',
      message:
          'Isso vai apagar todos os dados locais do MineControl (configurações, whitelist local e estado persistido). Deseja continuar?',
      confirmLabel: 'Continuar',
      confirmVariant: AppVariant.warning,
      confirmIcon: Icons.arrow_forward_rounded,
    );

    if (firstConfirm != true || !mounted) return;

    final secondConfirm = await showAppConfirmDialog(
      context,
      icon: Icons.delete_forever_rounded,
      title: 'Última confirmação',
      message: 'A operação é irreversível. Confirmar limpeza total agora?',
      cancelLabel: 'Voltar',
      confirmLabel: 'Limpar tudo',
      confirmVariant: AppVariant.danger,
      confirmIcon: Icons.delete_forever_rounded,
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
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ext.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ext.cardBorder.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppBadge(
              icon: Icons.warning_amber_rounded,
              color: scheme.error,
              title: 'Zona avançada: limpeza total de dados',
              description:
                  'Esta ação restaura a aplicação para o estado original e remove configurações, whitelist local, cache e dados persistidos.',
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
      ),
    );
  }
}
