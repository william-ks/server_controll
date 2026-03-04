import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/providers/theme_provider.dart';
import 'config/routes/app_router.dart';
import 'config/routes/routes_config.dart';
import 'config/theme/app_theme.dart';

class MineControlApp extends ConsumerWidget {
  const MineControlApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'MineControl',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      initialRoute: AppRoutes.home,
      routes: AppRouter.routes,
    );
  }
}
