import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'config/providers/theme_provider.dart';
import 'database/app_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!Platform.isAndroid && !Platform.isIOS && !Platform.isFuchsia) {
    await AppDatabase.instance.initializeDesktop();
  }

  await AppDatabase.instance.database;
  final savedTheme = await AppDatabase.instance.getSetting('theme_mode');
  final initialThemeMode = ThemeModeNotifier.fromStorageValue(savedTheme);

  runApp(
    ProviderScope(
      overrides: [
        themeInitialModeProvider.overrideWithValue(initialThemeMode),
      ],
      child: const MineControlApp(),
    ),
  );
}
