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
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _send() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      _focusNode.requestFocus();
      return;
    }
    widget.onSend(value);
    _controller.clear();
    _focusNode.requestFocus();
  }

  void _insertCommand(String command) {
    _controller.text = command;
    _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AppIconButton(
          icon: Icons.help_outline_rounded,
          onPressed: () {
            showDialog<void>(
              context: context,
              builder: (_) => QuickCommandsModal(onInsert: _insertCommand),
            );
          },
          tooltip: 'Comandos rápidos',
        ),
        const SizedBox(width: 8),
        Expanded(
          child: AppTextInput(
            controller: _controller,
            focusNode: _focusNode,
            hint: 'Digite um comando e pressione Enter',
            onSubmitted: (_) => _send(),
            suffixIcon: const Icon(Icons.terminal_rounded),
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
