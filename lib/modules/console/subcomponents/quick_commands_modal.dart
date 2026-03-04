import 'package:flutter/material.dart';

import '../../../components/buttons/app_button.dart';
import '../../../components/modal/app_modal.dart';

class QuickCommandsModal extends StatelessWidget {
  const QuickCommandsModal({super.key, required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final commands = <String>[
      'say Servidor administrado pelo MineControl',
      'list',
      'time set day',
    ];

    return AppModal(
      icon: Icons.menu_book_rounded,
      title: 'Comandos rápidos',
      width: 460,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final command in commands)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(command),
              onTap: () {
                onPick(command);
                Navigator.of(context).pop();
              },
            ),
        ],
      ),
      actions: [
        AppButton(
          label: 'Fechar',
          onPressed: () => Navigator.of(context).pop(),
          transparent: true,
          icon: Icons.close_rounded,
        ),
      ],
    );
  }
}
