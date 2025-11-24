import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:ironvault/core/providers.dart';

import '../secure_storage.dart';

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((
  ref,
) {
  final storage = ref.read(secureStorageProvider);
  return ThemeModeNotifier(storage);
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final SecureStorage storage;

  ThemeModeNotifier(this.storage) : super(ThemeMode.system) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final mode = await storage.readValue("app_theme");
    if (mode == "light") state = ThemeMode.light;
    if (mode == "dark") state = ThemeMode.dark;
    if (mode == "system" || mode == null) state = ThemeMode.system;
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;

    if (mode == ThemeMode.light) {
      await storage.writeValue("app_theme", "light");
    } else if (mode == ThemeMode.dark) {
      await storage.writeValue("app_theme", "dark");
    } else {
      await storage.writeValue("app_theme", "system");
    }
  }
}
