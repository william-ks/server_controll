import 'package:flutter/material.dart';

class WhitelistEmptyState extends StatelessWidget {
  const WhitelistEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.group_off_rounded, size: 40, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 8),
          const Text('Nenhum jogador cadastrado na whitelist.'),
        ],
      ),
    );
  }
}

