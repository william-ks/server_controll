import 'package:flutter/material.dart';

class QuickCommandsModal extends StatelessWidget {
  const QuickCommandsModal({super.key, required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final commands = <String>[
      'say Servidor administrado pelo MineControl',
      'list',
      'time set day',
    ];

    return Dialog(
      child: SizedBox(
        width: 420,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Comandos rápidos', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              for (final command in commands)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(command),
                  onTap: () {
                    onPick(command);
                    Navigator.of(context).pop();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

