import 'package:flutter/material.dart';

import '../../../components/inputs/app_text_input.dart';

class WhitelistAddPlayerForm extends StatefulWidget {
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
  State<WhitelistAddPlayerForm> createState() => _WhitelistAddPlayerFormState();
}

class _WhitelistAddPlayerFormState extends State<WhitelistAddPlayerForm> {
  late final TextEditingController _iconController;

  @override
  void initState() {
    super.initState();
    _iconController = TextEditingController(text: widget.iconPath ?? '');
  }

  @override
  void didUpdateWidget(covariant WhitelistAddPlayerForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.iconPath != widget.iconPath) {
      _iconController.text = widget.iconPath ?? '';
    }
  }

  @override
  void dispose() {
    _iconController.dispose();
    super.dispose();
  }

  Widget _fieldLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(context, 'Icone'),
        AppTextInput(
          controller: _iconController,
          hint: 'Ex.: C:\\imagens\\steve.png',
          readOnly: true,
          onTap: widget.onPickIcon,
          prefixIcon: const Icon(Icons.image_outlined),
          suffixIcon: IconButton(
            icon: const Icon(Icons.folder_open_rounded),
            tooltip: 'Selecionar arquivo',
            onPressed: widget.onPickIcon,
          ),
        ),
        const SizedBox(height: 12),
        _fieldLabel(context, 'Nickname'),
        AppTextInput(
          controller: widget.nicknameController,
          hint: 'Ex.: Steve',
          prefixIcon: const Icon(Icons.person_outline_rounded),
        ),
        const SizedBox(height: 12),
        _fieldLabel(context, 'UID'),
        AppTextInput(
          controller: widget.uuidController,
          hint: 'Ex.: 123e4567-e89b-12d3-a456-426614174000',
          prefixIcon: const Icon(Icons.tag_rounded),
        ),
      ],
    );
  }
}
