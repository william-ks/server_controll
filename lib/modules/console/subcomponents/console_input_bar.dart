import 'package:flutter/material.dart';

import '../../../components/buttons/app_icon_button.dart';
import '../../../components/inputs/app_text_input.dart';
import 'quick_commands_modal.dart';

class ConsoleInputBar extends StatefulWidget {
  const ConsoleInputBar({super.key, required this.onSend});

  final ValueChanged<String> onSend;

  @override
  State<ConsoleInputBar> createState() => _ConsoleInputBarState();
}

class _ConsoleInputBarState extends State<ConsoleInputBar> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      return;
    }
    widget.onSend(value);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AppIconButton(
          icon: Icons.menu_book_rounded,
          onPressed: () {
            showDialog<void>(
              context: context,
              builder: (_) => QuickCommandsModal(
                onPick: (command) {
                  _controller.text = command;
                  _send();
                },
              ),
            );
          },
          tooltip: 'Comandos rápidos',
          transparent: true,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: AppTextInput(
            controller: _controller,
            hint: 'Digite um comando e pressione Enter',
            onSubmitted: (_) => _send(),
          ),
        ),
        const SizedBox(width: 8),
        AppIconButton(
          icon: Icons.send_rounded,
          onPressed: _send,
          tooltip: 'Enviar comando',
        ),
      ],
    );
  }
}
