import 'package:flutter/material.dart';

import '../../../components/buttons/app_button.dart';
import '../../../components/modal/app_modal.dart';
import '../../../components/shared/app_variant.dart';
import '../models/whitelist_player.dart';
import 'whitelist_add_player_form.dart';

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
    return AppModal(
      icon: widget.player == null ? Icons.person_add_rounded : Icons.edit_rounded,
      title: widget.player == null ? 'Adicionar jogador' : 'Editar jogador',
      maxBodyHeight: 460,
      body: SizedBox(
        width: 520,
        child: WhitelistAddPlayerForm(
          nicknameController: _nicknameController,
          uuidController: _uuidController,
          iconPath: _iconPath,
          onPickIcon: () async {
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
        ),
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
          label: 'Salvar',
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
          variant: AppVariant.success,
          icon: Icons.check_rounded,
        ),
      ],
    );
  }
}
