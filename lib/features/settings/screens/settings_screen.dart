// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ironvault/core/theme/theme_provider.dart';
import 'package:ironvault/features/settings/about_screen.dart';
import 'package:ironvault/features/settings/security_tips_screen.dart';
import 'package:ironvault/core/providers.dart';
import 'package:ironvault/features/vault/screens/password_health_screen.dart';
import 'change_pin_screen.dart';
import 'package:ironvault/features/auth/screens/login_screen.dart';
import 'package:local_auth/local_auth.dart';
import 'package:ironvault/core/theme/app_tokens.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  final bool showAppBar;

  const SettingsScreen({super.key, this.showAppBar = true});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final storage = ref.read(secureStorageProvider);

    _biometricEnabled =
        (await storage.readValue("biometrics_enabled") ?? "false") == "true";

    if (mounted) setState(() {});
  }

  Future<void> _toggleBiometrics(bool value) async {
    final storage = ref.read(secureStorageProvider);
    final auth = LocalAuthentication();

    if (value) {
      final ok = await auth.authenticate(
        localizedReason: "Enable biometrics for IronVault",
        biometricOnly: true,
      );
      if (!ok) return;
      await storage.writeValue("biometrics_enabled", "true");
    } else {
      await storage.writeValue("biometrics_enabled", "false");
    }

    if (mounted) setState(() => _biometricEnabled = value);
  }

  Future<void> _toggleTheme(bool value) async {
    await ref
        .read(themeModeProvider.notifier)
        .setTheme(value ? ThemeMode.dark : ThemeMode.light);
  }

  Future<void> _logout() async {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    // final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDarkTheme = themeMode == ThemeMode.dark;
    final textColor = AppThemeColors.text(context);
    final textMuted = AppThemeColors.textMuted(context);

    return Scaffold(
      appBar: widget.showAppBar ? AppBar(title: const Text("Settings")) : null,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile header
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.12),
                  child: Icon(
                    Icons.person,
                    size: 28,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "IronVault User",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Your secure vault profile",
                        style: TextStyle(fontSize: 12, color: textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

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

          _switchTile(
            context,
            icon: Icons.fingerprint,
            title: "Enable Biometrics",
            subtitle: "Use fingerprint/face unlock",
            value: _biometricEnabled,
            onChanged: _toggleBiometrics,
          ),

          _autoLockTile(context, ref),

          _settingsTile(
            context,
            icon: Icons.health_and_safety,
            title: "Password Health",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PasswordHealthScreen()),
              );
            },
          ),

          const SizedBox(height: 20),
          _sectionTitle("Preferences"),

          _switchTile(
            context,
            icon: Icons.dark_mode,
            title: "Dark Mode",
            subtitle: "Use dark theme",
            value: isDarkTheme,
            onChanged: _toggleTheme,
          ),

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

          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: _logout,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text("Logout", style: TextStyle(fontSize: 16)),
          ),

          const SizedBox(height: 30),
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
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ListTile(
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: 0.12),
          child: Icon(
            icon,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(title),
        trailing: trailing ?? const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Widget _switchTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ListTile(
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: 0.12),
          child: Icon(
            icon,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Switch(value: value, onChanged: onChanged),
      ),
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
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const Text(
                "Auto-lock Timer",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
