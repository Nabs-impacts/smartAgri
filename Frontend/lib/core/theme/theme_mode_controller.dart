import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../i18n/language_controller.dart';

class ThemeModeController extends Notifier<ThemeMode> {
  static const String storageKey = 'app_theme_mode';

  @override
  ThemeMode build() {
    final SharedPreferences preferences = ref.watch(sharedPreferencesProvider);
    final String? stored = preferences.getString(storageKey);
    switch (stored) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref
        .read(sharedPreferencesProvider)
        .setString(storageKey, _value(mode));
  }

  String _value(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}

final NotifierProvider<ThemeModeController, ThemeMode>
themeModeControllerProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);
