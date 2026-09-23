import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themeModeKey = 'theme_mode';

class SettingsNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _load();
    return ThemeMode.system;
  }

  // Preference storage is a convenience, not a dependency of the game: if it
  // is unavailable the app still runs on the default theme.
  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_themeModeKey);
      if (saved == null) return;
      state = ThemeMode.values.firstWhere(
        (m) => m.name == saved,
        orElse: () => ThemeMode.system,
      );
    } catch (error) {
      debugPrint('Could not read the saved theme: $error');
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeModeKey, mode.name);
    } catch (error) {
      debugPrint('Could not persist the theme: $error');
    }
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, ThemeMode>(
  SettingsNotifier.new,
);
