import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'config/providers/theme_provider.dart';
import 'database/app_database.dart';
import 'modules/backup/models/backup_config_settings.dart';
import 'modules/backup/providers/backup_config_provider.dart';
import 'modules/config/models/config_files_settings.dart';
import 'modules/config/providers/config_files_provider.dart';
import 'modules/server/services/runtime_platform_bootstrap_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!Platform.isAndroid && !Platform.isIOS && !Platform.isFuchsia) {
    await AppDatabase.instance.initializeDesktop();
  }

  await AppDatabase.instance.database;
  await RuntimePlatformBootstrapService().applyStartupPlatformValidation();
  final savedTheme = await AppDatabase.instance.getSetting('theme_mode');
  final initialThemeMode = ThemeModeNotifier.fromStorageValue(savedTheme);
  final initialConfigFiles = await ConfigFilesSettings.fromDatabase(
    AppDatabase.instance,
  );
  final initialBackupConfig = await BackupConfigSettings.fromDatabase(
    AppDatabase.instance,
  );

  runApp(
    ProviderScope(
      overrides: [
        themeInitialModeProvider.overrideWithValue(initialThemeMode),
        configFilesInitialProvider.overrideWithValue(initialConfigFiles),
        backupConfigInitialProvider.overrideWithValue(initialBackupConfig),
      ],
      child: const MineControlApp(),
    ),
  );
}
