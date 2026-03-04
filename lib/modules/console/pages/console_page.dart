import 'package:flutter/material.dart';

import '../../../layout/default_layout.dart';
import '../../../routes/routes_config.dart';

class ConsolePage extends StatelessWidget {
  const ConsolePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultLayout(
      title: 'MineControl',
      currentRoute: AppRoutes.console,
      child: Center(child: Text('Console placeholder')),
    );
  }
}
