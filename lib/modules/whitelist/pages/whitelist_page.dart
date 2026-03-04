import 'package:flutter/material.dart';

import '../../../layout/default_layout.dart';
import '../../../routes/routes_config.dart';

class WhitelistPage extends StatelessWidget {
  const WhitelistPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultLayout(
      title: 'MineControl',
      currentRoute: AppRoutes.whitelist,
      child: Center(child: Text('Whitelist placeholder')),
    );
  }
}
