import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/buttons/app_button.dart';
import '../../../components/inputs/app_text_input.dart';
import '../../../components/modal/app_modal.dart';
import '../../../components/shared/app_variant.dart';
import '../../server/providers/server_runtime_provider.dart';
import '../../server/services/minecraft_command_provider.dart';

enum KickMode { all, one, many }

class KickPlayersModal extends ConsumerStatefulWidget {
  const KickPlayersModal({super.key});

  @override
  ConsumerState<KickPlayersModal> createState() => _KickPlayersModalState();
}

class _KickPlayersModalState extends ConsumerState<KickPlayersModal> {
  static const _commands = MinecraftCommandProvider.vanilla;
  KickMode _mode = KickMode.all;
  String? _singlePlayer;
  final Set<String> _manyPlayers = <String>{};
  final TextEditingController _messageController = TextEditingController(
    text: 'Desconectado pelo servidor',
  );

  @override
  void initState() {
    super.initState();
    Future<void>(
      () => ref.read(serverRuntimeProvider.notifier).requestOnlinePlayers(),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final message = _messageController.text.trim().isEmpty
        ? 'Desconectado pelo servidor'
        : _messageController.text.trim();
    final notifier = ref.read(serverRuntimeProvider.notifier);

    if (_mode == KickMode.all) {
      await notifier.sendCommand(_commands.kick('@a', message));
    } else if (_mode == KickMode.one && _singlePlayer != null) {
      await notifier.sendCommand(_commands.kick(_singlePlayer!, message));
    } else if (_mode == KickMode.many && _manyPlayers.isNotEmpty) {
      for (final player in _manyPlayers) {
        await notifier.sendCommand(_commands.kick(player, message));
      }
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final players = ref.watch(onlinePlayersProvider);

    return AppModal(
      icon: Icons.person_off_rounded,
      title: 'Kick Players',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SegmentedButton<KickMode>(
            segments: const [
              ButtonSegment(value: KickMode.all, label: Text('Todos')),
              ButtonSegment(value: KickMode.one, label: Text('Um')),
              ButtonSegment(value: KickMode.many, label: Text('Vários')),
            ],
            selected: <KickMode>{_mode},
            onSelectionChanged: (value) {
              setState(() {
                _mode = value.first;
              });
            },
          ),
          const SizedBox(height: 12),
          if (_mode == KickMode.one)
            DropdownButtonFormField<String>(
              initialValue: _singlePlayer,
              decoration: const InputDecoration(labelText: 'Jogador'),
              items: players
                  .map(
                    (player) =>
                        DropdownMenuItem(value: player, child: Text(player)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _singlePlayer = value),
            ),
          if (_mode == KickMode.many)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: ListView(
                shrinkWrap: true,
                children: players
                    .map(
                      (player) => CheckboxListTile(
                        value: _manyPlayers.contains(player),
                        onChanged: (checked) {
                          setState(() {
                            if (checked ?? false) {
                              _manyPlayers.add(player);
                            } else {
                              _manyPlayers.remove(player);
                            }
                          });
                        },
                        title: Text(player),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    )
                    .toList(),
              ),
            ),
          const SizedBox(height: 12),
          AppTextInput(
            controller: _messageController,
            label: 'Mensagem de desconexão',
            hint: 'Desconectado pelo servidor',
          ),
        ],
      ),
      actions: [
        AppButton(
          label: 'Cancelar',
          onPressed: () => Navigator.of(context).pop(),
          variant: AppVariant.danger,
          transparent: true,
          icon: Icons.close_rounded,
        ),
        AppButton(
          label: 'Confirmar',
          onPressed: _confirm,
          variant: AppVariant.success,
          icon: Icons.check_rounded,
        ),
      ],
    );
  }
}
