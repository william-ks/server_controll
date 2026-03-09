import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../components/buttons/app_button.dart';
import '../../../components/modal/app_modal.dart';
import '../../../components/shared/app_variant.dart';
import '../../../config/theme/app_theme_extension.dart';
import '../../server/services/minecraft_command_provider.dart';

class QuickCommandItem {
  const QuickCommandItem({
    required this.title,
    required this.description,
    required this.displayCommand,
    required this.rawCommand,
  });

  final String title;
  final String description;
  final String displayCommand;
  final String rawCommand;
}

class QuickCommandsModal extends StatelessWidget {
  const QuickCommandsModal({super.key, required this.onInsert});

  final ValueChanged<String> onInsert;

  @override
  Widget build(BuildContext context) {
    const commandsProvider = MinecraftCommandProvider.vanilla;
    final commands = <QuickCommandItem>[
      QuickCommandItem(
        title: 'Enviar mensagem',
        description: 'Envia uma mensagem no chat do servidor.',
        displayCommand: '/say <mensagem>',
        rawCommand: commandsProvider.say('<mensagem>'),
      ),
      QuickCommandItem(
        title: 'Listar jogadores',
        description: 'Mostra os jogadores online no momento.',
        displayCommand: '/list',
        rawCommand: commandsProvider.listPlayers(),
      ),
      QuickCommandItem(
        title: 'Desconectar jogador',
        description: 'Remove um jogador online com mensagem personalizada.',
        displayCommand: '/kick <jogador> "<mensagem>"',
        rawCommand: commandsProvider.kick('<jogador>', '"<mensagem>"'),
      ),
      QuickCommandItem(
        title: 'Definir dia',
        description: 'Ajusta o tempo do mundo para período diurno.',
        displayCommand: '/time set day',
        rawCommand: commandsProvider.timeSetDay(),
      ),
      const QuickCommandItem(
        title: 'Borda do mundo (tamanho)',
        description: 'Define o tamanho total da World Border.',
        displayCommand: '/worldborder set <tamanho>',
        rawCommand: '/worldborder set <tamanho>',
      ),
      const QuickCommandItem(
        title: 'Borda para 1000',
        description: 'Define a borda para 1000 blocos.',
        displayCommand: '/worldborder set 1000',
        rawCommand: '/worldborder set 1000',
      ),
      const QuickCommandItem(
        title: 'Borda para 1000 em 10s',
        description: 'Expande ou reduz para 1000 em 10 segundos.',
        displayCommand: '/worldborder set 1000 10',
        rawCommand: '/worldborder set 1000 10',
      ),
      const QuickCommandItem(
        title: 'Centralizar borda',
        description: 'Define o centro da borda em X/Z.',
        displayCommand: '/worldborder center <x> <z>',
        rawCommand: '/worldborder center <x> <z>',
      ),
      const QuickCommandItem(
        title: 'Centro em 0 0',
        description: 'Centraliza a borda na origem.',
        displayCommand: '/worldborder center 0 0',
        rawCommand: '/worldborder center 0 0',
      ),
      const QuickCommandItem(
        title: 'Ver tamanho da borda',
        description: 'Mostra o tamanho atual da World Border.',
        displayCommand: '/worldborder get',
        rawCommand: '/worldborder get',
      ),
      const QuickCommandItem(
        title: 'Adicionar/remover borda',
        description: 'Aumenta ou reduz tamanho relativo da borda.',
        displayCommand: '/worldborder add <tamanho>',
        rawCommand: '/worldborder add <tamanho>',
      ),
      const QuickCommandItem(
        title: 'Diminuir borda em 100',
        description: 'Reduz a borda em 100 blocos.',
        displayCommand: '/worldborder add -100',
        rawCommand: '/worldborder add -100',
      ),
      const QuickCommandItem(
        title: 'Aviso de distância',
        description: 'Mostra aviso visual a X blocos da borda.',
        displayCommand: '/worldborder warning distance <blocos>',
        rawCommand: '/worldborder warning distance <blocos>',
      ),
      const QuickCommandItem(
        title: 'Aviso em 10 blocos',
        description: 'Ativa aviso visual quando faltar 10 blocos.',
        displayCommand: '/worldborder warning distance 10',
        rawCommand: '/worldborder warning distance 10',
      ),
      const QuickCommandItem(
        title: 'Aviso por tempo',
        description: 'Define aviso para borda encolhendo por tempo.',
        displayCommand: '/worldborder warning time <segundos>',
        rawCommand: '/worldborder warning time <segundos>',
      ),
      const QuickCommandItem(
        title: 'Aviso de 15s',
        description: 'Ativa aviso de tempo em 15 segundos.',
        displayCommand: '/worldborder warning time 15',
        rawCommand: '/worldborder warning time 15',
      ),
      const QuickCommandItem(
        title: 'Fechar borda no tempo',
        description: 'Define tamanho final e tempo de fechamento.',
        displayCommand: '/worldborder set <tamanho_final> <tempo_em_segundos>',
        rawCommand: '/worldborder set <tamanho_final> <tempo_em_segundos>',
      ),
      const QuickCommandItem(
        title: 'Evento: 5000 para 500',
        description: 'Fecha de 5000 para 500 em 30 minutos.',
        displayCommand: '/worldborder set 500 1800',
        rawCommand: '/worldborder set 500 1800',
      ),
      const QuickCommandItem(
        title: 'Evento completo (1/4)',
        description: 'Centraliza a borda no spawn.',
        displayCommand: '/worldborder center 0 0',
        rawCommand: '/worldborder center 0 0',
      ),
      const QuickCommandItem(
        title: 'Evento completo (2/4)',
        description: 'Começa com borda de 5000 blocos.',
        displayCommand: '/worldborder set 5000',
        rawCommand: '/worldborder set 5000',
      ),
      const QuickCommandItem(
        title: 'Evento completo (3/4)',
        description: 'Avisa jogador a 20 blocos da borda.',
        displayCommand: '/worldborder warning distance 20',
        rawCommand: '/worldborder warning distance 20',
      ),
      const QuickCommandItem(
        title: 'Evento completo (4/4)',
        description: 'Fecha até 200 blocos em 1 hora.',
        displayCommand: '/worldborder set 200 3600',
        rawCommand: '/worldborder set 200 3600',
      ),
      const QuickCommandItem(
        title: 'Desativar mobs persistentes',
        description: 'Define gamerule persistentAnimals como false.',
        displayCommand: '/gamerule persistentAnimals false',
        rawCommand: '/gamerule persistentAnimals false',
      ),
    ];

    return AppModal(
      icon: Icons.help_outline_rounded,
      title: 'Comandos rápidos',
      width: 700,
      maxBodyHeight: 430,
      body: ListView.separated(
        shrinkWrap: true,
        itemCount: commands.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, index) {
          final item = commands[index];
          return QuickCommandCard(item: item, onInsert: onInsert);
        },
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
    final ext = theme.extension<AppThemeExtension>()!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color:
                        theme.inputDecorationTheme.fillColor ??
                        theme.colorScheme.surface,
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
                        onPressed: () => Clipboard.setData(
                          ClipboardData(text: item.rawCommand),
                        ),
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
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
