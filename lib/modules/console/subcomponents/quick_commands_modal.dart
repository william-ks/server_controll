import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../components/buttons/app_button.dart';
import '../../../components/modal/app_modal.dart';
import '../../../components/shared/app_variant.dart';

class QuickCommandItem {
  const QuickCommandItem({
    required this.title,
    required this.description,
    required this.displayCommand,
    required this.rawCommand,
    this.example,
  });

  final String title;
  final String description;
  final String displayCommand;
  final String rawCommand;
  final String? example;
}

class QuickCommandsModal extends StatelessWidget {
  const QuickCommandsModal({super.key, required this.onInsert});

  final ValueChanged<String> onInsert;

  @override
  Widget build(BuildContext context) {
    final commands = <QuickCommandItem>[
      const QuickCommandItem(
        title: 'Enviar mensagem',
        description: 'Envia uma mensagem no chat do servidor.',
        displayCommand: '/say <mensagem>',
        rawCommand: 'say <mensagem>',
        example: 'Ex.: /say <mensagem>',
      ),
      const QuickCommandItem(
        title: 'Listar jogadores',
        description: 'Mostra os jogadores online no momento.',
        displayCommand: '/list',
        rawCommand: 'list',
        example: 'Ex.: /list',
      ),
      const QuickCommandItem(
        title: 'Desconectar jogador',
        description: 'Remove um jogador online com mensagem personalizada.',
        displayCommand: '/kick <jogador> "<mensagem>"',
        rawCommand: 'kick <jogador> "<mensagem>"',
        example: 'Ex.: /kick <jogador> "servidor administrado pelo Minecontrol"',
      ),
      const QuickCommandItem(
        title: 'Definir dia',
        description: 'Ajusta o tempo do mundo para período diurno.',
        displayCommand: '/time set day',
        rawCommand: 'time set day',
        example: 'Ex.: /time set day',
      ),
    ];

    return AppModal(
      icon: Icons.help_outline_rounded,
      title: 'Comandos rápidos',
      width: 700,
      maxBodyHeight: 500,
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
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.inputDecorationTheme.fillColor ?? theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.displayCommand,
                          style: const TextStyle(fontFamily: 'Consolas'),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Copiar comando',
                        onPressed: () => Clipboard.setData(ClipboardData(text: item.rawCommand)),
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
                if (item.example != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    item.example!,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Inserir no input',
                icon: const Icon(Icons.east_rounded),
                onPressed: () {
                  onInsert(item.rawCommand);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
