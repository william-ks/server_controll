import 'package:flutter/material.dart';

import '../../../components/buttons/app_button.dart';
import '../../../components/shared/app_variant.dart';

class WhitelistActionsBar extends StatelessWidget {
  const WhitelistActionsBar({
    super.key,
    required this.onAdd,
    required this.onRefresh,
    required this.onSyncPending,
  });

  final VoidCallback onAdd;
  final VoidCallback onRefresh;
  final VoidCallback onSyncPending;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        AppButton(
          label: 'Adicionar jogador',
          icon: Icons.person_add_alt_1_rounded,
          onPressed: onAdd,
          variant: AppVariant.primary,
        ),
        AppButton(
          label: 'Refresh',
          icon: Icons.refresh_rounded,
          onPressed: onRefresh,
          variant: AppVariant.info,
          transparent: true,
        ),
        AppButton(
          label: 'Sincronizar',
          icon: Icons.sync_rounded,
          onPressed: onSyncPending,
          variant: AppVariant.warning,
          transparent: true,
        ),
      ],
    );
  }
}
