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

  ThemeModeNotifier(this.storage) : super(ThemeMode.light) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final mode = await storage.readValue("app_theme");
    if (mode == "dark") {
      state = ThemeMode.dark;
    } else {
      // Default to light if unset or any legacy value (including "system")
      state = ThemeMode.light;
    }
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;

    if (mode == ThemeMode.light) {
      await storage.writeValue("app_theme", "light");
    } else if (mode == ThemeMode.dark) {
      await storage.writeValue("app_theme", "dark");
    }
  }
}
