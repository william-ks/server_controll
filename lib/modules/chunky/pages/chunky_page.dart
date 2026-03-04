import 'package:flutter/material.dart';

import '../../../config/routes/routes_config.dart';
import '../../../layout/default_layout.dart';

class ChunkyPage extends StatelessWidget {
  const ChunkyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultLayout(
      title: 'MineControl',
      currentRoute: AppRoutes.chunky,
      child: _ChunkyBody(),
    );
  }
}

class _ChunkyBody extends StatelessWidget {
  const _ChunkyBody();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        padding: const EdgeInsets.all(20),
        child: const Text('Módulo Chunky em construção.'),
      ),
    );
  }
}
