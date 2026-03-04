import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/app_database.dart';

final themeInitialModeProvider = Provider<ThemeMode>((_) => ThemeMode.dark);

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const String _settingKey = 'theme_mode';

  static ThemeMode fromStorageValue(String? value) {
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };
  }

  static String toStorageValue(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
  }

  @override
  ThemeMode build() {
    return ref.read(themeInitialModeProvider);
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await AppDatabase.instance.setSetting(_settingKey, toStorageValue(mode));
  }

  Future<void> toggle() async {
    final next = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setMode(next);
  }
}
