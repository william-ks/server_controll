import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import '../../../components/buttons/app_button.dart';
import '../../../components/modal/app_modal.dart';
import '../../../components/shared/app_variant.dart';

class QuickCommandItem {
  const QuickCommandItem({
    required this.command,
    required this.title,
    required this.description,
  });

  final String command;
  final String title;
  final String description;
}

class QuickCommandsModal extends StatelessWidget {
  const QuickCommandsModal({super.key, required this.onInsert});

  final ValueChanged<String> onInsert;

  @override
  Widget build(BuildContext context) {
    final commands = <QuickCommandItem>[
      const QuickCommandItem(
        command: 'say Servidor administrado pelo MineControl',
        title: 'Anunciar mensagem',
        description: 'Envia uma mensagem global no chat para todos os jogadores.',
      ),
      const QuickCommandItem(
        command: 'list',
        title: 'Listar jogadores',
        description: 'Mostra jogadores online e total de conectados.',
      ),
      const QuickCommandItem(
        command: 'time set day',
        title: 'Definir dia',
        description: 'Ajusta o tempo do mundo para período diurno.',
      ),
    ];

    return AppModal(
      icon: Icons.menu_book_rounded,
      title: 'Comandos rápidos',
      width: 640,
      maxBodyHeight: 460,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in commands) ...[
            QuickCommandCard(item: item, onInsert: onInsert),
            const SizedBox(height: 10),
          ],
        ],
      ),
      actions: [
        AppButton(
          label: 'Fechar',
          onPressed: () => Navigator.of(context).pop(),
          variant: AppVariant.danger,
          transparent: true,
          icon: Icons.close_rounded,
        ),
      ],
    );
  }
}

class QuickCommandCard extends StatelessWidget {
  const QuickCommandCard({
    super.key,
    required this.item,
    required this.onInsert,
  });

  final QuickCommandItem item;
  final ValueChanged<String> onInsert;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(item.description, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          SelectableText(item.command, style: const TextStyle(fontFamily: 'Consolas')),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              AppButton(
                label: 'Copiar',
                icon: Icons.copy_rounded,
                onPressed: () => Clipboard.setData(ClipboardData(text: item.command)),
                transparent: true,
              ),
              AppButton(
                label: 'Inserir no input',
                icon: Icons.east_rounded,
                onPressed: () => onInsert(item.command),
                variant: AppVariant.info,
                transparent: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
