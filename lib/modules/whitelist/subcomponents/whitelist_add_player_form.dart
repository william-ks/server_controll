import 'package:flutter/material.dart';

import '../../../components/buttons/app_button.dart';
import '../../../components/inputs/app_text_input.dart';

class WhitelistAddPlayerForm extends StatelessWidget {
  const WhitelistAddPlayerForm({
    super.key,
    required this.nicknameController,
    required this.uuidController,
    required this.iconPath,
    required this.onPickIcon,
  });

  final TextEditingController nicknameController;
  final TextEditingController uuidController;
  final String? iconPath;
  final Future<void> Function() onPickIcon;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => onPickIcon(),
          child: Ink(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Theme.of(context).dividerColor),
              color: Theme.of(context).inputDecorationTheme.fillColor,
            ),
            child: Row(
              children: [
                const Icon(Icons.image_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    iconPath == null ? 'Selecionar ícone do jogador' : iconPath!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                AppButton(
                  label: 'Escolher',
                  icon: Icons.upload_file_rounded,
                  onPressed: () => onPickIcon(),
                  transparent: true,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        AppTextInput(
          controller: nicknameController,
          label: 'Nickname',
          hint: 'Ex.: Steve',
          prefixIcon: const Icon(Icons.person_outline_rounded),
        ),
        const SizedBox(height: 12),
        AppTextInput(
          controller: uuidController,
          label: 'ID (UUID)',
          hint: 'Ex.: 123e4567-e89b-12d3-a456-426614174000',
          prefixIcon: const Icon(Icons.tag_rounded),
        ),
      ],
    );
  }
}
