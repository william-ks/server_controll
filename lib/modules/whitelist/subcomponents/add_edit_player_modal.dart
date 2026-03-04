import 'package:flutter/material.dart';

import '../models/whitelist_player.dart';

class AddEditPlayerModal extends StatefulWidget {
  const AddEditPlayerModal({
    super.key,
    this.player,
    required this.onSave,
    required this.onPickIcon,
  });

  final WhitelistPlayer? player;
  final Future<void> Function({required String nickname, String? uuid, String? iconPath}) onSave;
  final Future<String?> Function(String nickname) onPickIcon;

  @override
  State<AddEditPlayerModal> createState() => _AddEditPlayerModalState();
}

class _AddEditPlayerModalState extends State<AddEditPlayerModal> {
  late final TextEditingController _nicknameController;
  late final TextEditingController _uuidController;
  String? _iconPath;

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController(text: widget.player?.nickname ?? '');
    _uuidController = TextEditingController(text: widget.player?.uuid ?? '');
    _iconPath = widget.player?.iconPath;
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _uuidController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.player == null ? 'Adicionar jogador' : 'Editar jogador'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nicknameController,
              decoration: const InputDecoration(labelText: 'Nickname'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _uuidController,
              decoration: const InputDecoration(labelText: 'UUID (opcional)'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _iconPath == null ? 'Sem ícone' : _iconPath!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final nickname = _nicknameController.text.trim();
                    if (nickname.isEmpty) {
                      return;
                    }
                    final path = await widget.onPickIcon(nickname);
                    if (path == null) {
                      return;
                    }
                    setState(() => _iconPath = path);
                  },
                  child: const Text('Escolher ícone'),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () async {
            await widget.onSave(
              nickname: _nicknameController.text,
              uuid: _uuidController.text,
              iconPath: _iconPath,
            );
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
