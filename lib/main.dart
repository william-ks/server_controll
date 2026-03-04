import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database/app_database.dart';
import 'providers/theme_provider.dart';
import 'routes/app_router.dart';
import 'routes/routes_config.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!Platform.isAndroid && !Platform.isIOS && !Platform.isFuchsia) {
    await AppDatabase.instance.initializeDesktop();
  }
  await AppDatabase.instance.database;
  runApp(const ProviderScope(child: MineControlApp()));
}

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
