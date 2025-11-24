// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ironvault/core/theme/theme_provider.dart';
import 'package:ironvault/features/settings/about_screen.dart';
import 'package:ironvault/features/settings/security_tips_screen.dart';
import 'package:ironvault/core/providers.dart';
import 'change_pin_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle("Security"),

          _settingsTile(
            context,
            icon: Icons.password,
            title: "Change Master PIN",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChangePinScreen()),
              );
            },
          ),

          _biometricToggle(context, ref),

          _autoLockTile(context, ref),

          const SizedBox(height: 20),
          _sectionTitle("Appearance"),

          _themeSelector(context, ref, themeMode),

          const SizedBox(height: 20),
          _sectionTitle("Help & Info"),

          _settingsTile(
            context,
            icon: Icons.security,
            title: "Security Tips",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SecurityTipsScreen()),
              );
            },
          ),

          _settingsTile(
            context,
            icon: Icons.info_outline,
            title: "About",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AboutScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  // ---------------- UI HELPERS ----------------

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _settingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: ListTile(
        leading: Icon(icon, size: 24),
        title: Text(title),
        trailing: trailing ?? const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  // BIOMETRIC TOGGLE
  Widget _biometricToggle(BuildContext context, WidgetRef ref) {
    return FutureBuilder(
      future: ref.read(secureStorageProvider).readValue("biometrics_enabled"),
      builder: (context, snapshot) {
        final enabled = snapshot.data == "true";

        return _settingsTile(
          context,
          icon: Icons.fingerprint,
          title: "Enable Biometrics",
          trailing: Switch(
            value: enabled,
            onChanged: (value) async {
              await ref
                  .read(secureStorageProvider)
                  .writeValue("biometrics_enabled", value ? "true" : "false");
              (context as Element).markNeedsBuild();
            },
          ),
        );
      },
    );
  }

  // AUTO-LOCK TIMER TILE
  Widget _autoLockTile(BuildContext context, WidgetRef ref) {
    return _settingsTile(
      context,
      icon: Icons.lock_clock,
      title: "Auto-lock Timer",
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        showModalBottomSheet(
          context: context,
          builder: (_) => const _AutoLockSheet(),
        );
      },
    );
  }

  // THEME SELECTOR TILE
  Widget _themeSelector(BuildContext context, WidgetRef ref, ThemeMode mode) {
    return _settingsTile(
      context,
      icon: Icons.color_lens,
      title: "Theme",
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        showModalBottomSheet(
          context: context,
          builder: (_) => const _ThemeSelectorSheet(),
        );
      },
    );
  }
}

// ---------------- AUTO LOCK SHEET ----------------

class _AutoLockSheet extends ConsumerWidget {
  const _AutoLockSheet();

  static const options = {
    "immediately": "Immediately",
    "10": "After 10 seconds",
    "30": "After 30 seconds",
    "60": "After 1 minute",
    "300": "After 5 minutes",
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder(
      future: ref.read(secureStorageProvider).readValue("auto_lock_timer"),
      builder: (context, snapshot) {
        final selected = snapshot.data ?? "immediately";

        return Container(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Auto-lock Timer",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              ...options.entries.map((entry) {
                final key = entry.key;
                final label = entry.value;

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    key == selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                  ),
                  title: Text(label),
                  onTap: () async {
                    await ref
                        .read(secureStorageProvider)
                        .writeValue("auto_lock_timer", key);

                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

// ---------------- THEME SELECTOR SHEET ----------------

class _ThemeSelectorSheet extends ConsumerWidget {
  const _ThemeSelectorSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    Widget option({
      required ThemeMode mode,
      required String label,
      required IconData icon,
    }) {
      final bool selected = themeMode == mode;

      return ListTile(
        leading: Icon(icon, color: selected ? Colors.blueAccent : null),
        title: Text(label),
        trailing: Icon(
          selected ? Icons.check_circle : Icons.circle_outlined,
          color: selected ? Colors.blueAccent : null,
        ),
        onTap: () {
          ref.read(themeModeProvider.notifier).setTheme(mode);
          Navigator.pop(context);
        },
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "Choose Theme",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 12),

          option(
            mode: ThemeMode.system,
            label: "System Default",
            icon: Icons.phone_android,
          ),

          option(
            mode: ThemeMode.light,
            label: "Light Mode",
            icon: Icons.light_mode,
          ),

          option(
            mode: ThemeMode.dark,
            label: "Dark Mode",
            icon: Icons.dark_mode,
          ),
        ],
      ),
    );
  }
}
