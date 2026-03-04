import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'config/providers/theme_provider.dart';
import 'database/app_database.dart';
import 'modules/config/models/config_files_settings.dart';
import 'modules/config/providers/config_files_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!Platform.isAndroid && !Platform.isIOS && !Platform.isFuchsia) {
    await AppDatabase.instance.initializeDesktop();
  }

  await AppDatabase.instance.database;
  final savedTheme = await AppDatabase.instance.getSetting('theme_mode');
  final initialThemeMode = ThemeModeNotifier.fromStorageValue(savedTheme);
  final initialConfigFiles = await ConfigFilesSettings.fromDatabase(AppDatabase.instance);

  runApp(
    ProviderScope(
      overrides: [
        themeInitialModeProvider.overrideWithValue(initialThemeMode),
        configFilesInitialProvider.overrideWithValue(initialConfigFiles),
      ],
      child: const MineControlApp(),
    ),
  );
}
