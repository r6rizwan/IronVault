// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ironvault/core/autolock/auto_lock_provider.dart';
import 'package:ironvault/core/theme/theme_provider.dart';
import 'package:ironvault/core/providers.dart';
import 'package:ironvault/core/services/crash_reporter.dart';
import 'package:ironvault/features/settings/screens/about_screen.dart';
import 'package:ironvault/features/vault/screens/password_health_screen.dart';
import 'change_pin_screen.dart';
import 'package:ironvault/features/auth/screens/pin_unlock_screen.dart';
import 'package:local_auth/local_auth.dart';
import 'package:ironvault/core/utils/app_reauth_util.dart';
import 'package:ironvault/features/auth/screens/recovery_key_screen.dart';
import 'package:ironvault/core/backup/backup_service.dart';
import 'package:ironvault/core/backup/csv_import_service.dart';
import 'package:ironvault/core/backup/csv_export_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  final bool showAppBar;

  const SettingsScreen({super.key, this.showAppBar = true});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _biometricEnabled = false;
  bool _lockOnSwitch = true;
  bool _hasRecoveryKey = true;
  bool _clipboardDisabled = false;
  String _autoLockTimer = "immediately";
  late final String _securityTip;

  static const List<String> _securityTips = [
    'Use a unique master PIN and avoid easy patterns.',
    'Save your recovery key somewhere secure and offline.',
    'Enable biometrics for faster and safer unlocks.',
    'Review Password Health regularly to spot weak entries.',
  ];

  @override
  void initState() {
    super.initState();
    _securityTip =
        _securityTips[DateTime.now().microsecondsSinceEpoch %
            _securityTips.length];
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final storage = ref.read(secureStorageProvider);

    _biometricEnabled =
        (await storage.readValue("biometrics_enabled") ?? "false") == "true";
    _lockOnSwitch =
        (await storage.readValue("auto_lock_on_switch") ?? "true") == "true";
    _autoLockTimer =
        await storage.readValue("auto_lock_timer") ?? "immediately";
    _clipboardDisabled =
        (await storage.readValue("disable_clipboard_copy") ?? "false") ==
        "true";
    _hasRecoveryKey = (await storage.readRecoveryKeyHash()) != null;

    if (mounted) setState(() {});
  }

  Future<void> _toggleBiometrics(bool value) async {
    final storage = ref.read(secureStorageProvider);
    final auth = LocalAuthentication();

    if (value) {
      try {
        final ok = await auth.authenticate(
          localizedReason: "Enable biometrics for IronVault",
          biometricOnly: true,
        );
        if (!ok) return;
      } on Exception catch (_) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Biometrics not set'),
              content: const Text(
                'Set up fingerprint or face unlock in your device settings.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
          setState(() => _biometricEnabled = false);
        }
        return;
      }
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

  Future<void> _toggleLockOnSwitch(bool value) async {
    await ref.read(autoLockProvider.notifier).setLockOnSwitch(value);
    if (mounted) setState(() => _lockOnSwitch = value);
  }

  Future<void> _toggleClipboardDisabled(bool value) async {
    final storage = ref.read(secureStorageProvider);
    await storage.writeValue(
      'disable_clipboard_copy',
      value ? 'true' : 'false',
    );
    if (mounted) setState(() => _clipboardDisabled = value);
  }

  Future<void> _exportBackup() async {
    final ctx = context;
    final passCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? error;

    final confirm = await showDialog<bool>(
      context: ctx,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setLocal) => AlertDialog(
            title: const Text('Create Encrypted Backup'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Backup password',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: confirmCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Confirm password',
                    errorText: error,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Keep this password safe. You will need it to restore this backup later.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  final p1 = passCtrl.text.trim();
                  final p2 = confirmCtrl.text.trim();
                  if (p1.length < 6) {
                    setLocal(() => error = 'Use at least 6 characters');
                    return;
                  }
                  if (p1 != p2) {
                    setLocal(() => error = 'Passwords do not match');
                    return;
                  }
                  Navigator.pop(context, true);
                },
                child: const Text('Export'),
              ),
            ],
          ),
        );
      },
    );

    if (confirm != true) return;
    if (!ctx.mounted) return;

    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        title: Text('Creating backup'),
        content: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Please wait...'),
          ],
        ),
      ),
    );

    try {
      ref.read(autoLockProvider.notifier).suspendAutoLock();
      try {
        final service = BackupService(repo: ref.read(credentialRepoProvider));
        final file = await service.exportEncryptedBackup(
          password: passCtrl.text.trim(),
        );
        if (!ctx.mounted) return;
        Navigator.pop(ctx);
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            text: 'IronVault encrypted backup',
          ),
        );
      } finally {
        ref.read(autoLockProvider.notifier).resumeAutoLock();
      }
    } catch (e) {
      await CrashReporter.captureException(
        e,
        StackTrace.current,
        feature: 'backup',
        action: 'export_encrypted_backup',
      );
      if (!ctx.mounted) return;
      Navigator.pop(ctx);
      showDialog(
        context: ctx,
        builder: (_) => AlertDialog(
          title: const Text('Backup failed'),
          content: Text('Could not export backup: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _importBackup() async {
    final ctx = context;
    final pick = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['ivault'],
    );
    if (pick == null || pick.files.isEmpty) return;
    final path = pick.files.first.path;
    if (path == null) return;

    final passCtrl = TextEditingController();
    String? error;

    final confirm = await showDialog<bool>(
      context: ctx,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setLocal) => AlertDialog(
            title: const Text('Restore Encrypted Backup'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Backup password',
                    errorText: error,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This will add items from the backup to your vault.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  final p1 = passCtrl.text.trim();
                  if (p1.isEmpty) {
                    setLocal(() => error = 'Enter backup password');
                    return;
                  }
                  Navigator.pop(context, true);
                },
                child: const Text('Import'),
              ),
            ],
          ),
        );
      },
    );

    if (confirm != true) return;
    if (!ctx.mounted) return;

    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        title: Text('Importing backup'),
        content: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Please wait...'),
          ],
        ),
      ),
    );

    try {
      ref.read(autoLockProvider.notifier).suspendAutoLock();
      try {
        final service = BackupService(repo: ref.read(credentialRepoProvider));
        final count = await service.importEncryptedBackup(
          file: File(path),
          password: passCtrl.text.trim(),
        );
        ref.read(vaultRefreshProvider.notifier).state++;
        if (!ctx.mounted) return;
        Navigator.pop(ctx);
        showDialog(
          context: ctx,
          builder: (_) => AlertDialog(
            title: const Text('Import complete'),
            content: Text('Imported $count item(s).'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } finally {
        ref.read(autoLockProvider.notifier).resumeAutoLock();
      }
    } catch (e) {
      await CrashReporter.captureException(
        e,
        StackTrace.current,
        feature: 'backup',
        action: 'import_encrypted_backup',
      );
      if (!ctx.mounted) return;
      Navigator.pop(ctx);
      showDialog(
        context: ctx,
        builder: (_) => AlertDialog(
          title: const Text('Import failed'),
          content: Text('Could not import backup: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _importCsv() async {
    final ctx = context;
    final pick = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (pick == null || pick.files.isEmpty) return;
    final path = pick.files.first.path;
    if (path == null) return;

    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        title: Text('Importing CSV'),
        content: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Please wait...'),
          ],
        ),
      ),
    );

    try {
      ref.read(autoLockProvider.notifier).suspendAutoLock();
      try {
        final service = CsvImportService(repo: ref.read(credentialRepoProvider));
        final result = await service.importPasswords(File(path));
        ref.read(vaultRefreshProvider.notifier).state++;
        if (!ctx.mounted) return;
        Navigator.pop(ctx);
        showDialog(
          context: ctx,
          builder: (_) => AlertDialog(
            title: const Text('CSV import complete'),
            content: Text(
              'Imported ${result.imported} item(s).'
              '${result.skipped > 0 ? " Skipped ${result.skipped} row(s)." : ""}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } finally {
        ref.read(autoLockProvider.notifier).resumeAutoLock();
      }
    } catch (e) {
      await CrashReporter.captureException(
        e,
        StackTrace.current,
        feature: 'import_export',
        action: 'import_csv',
      );
      if (!ctx.mounted) return;
      Navigator.pop(ctx);
      showDialog(
        context: ctx,
        builder: (_) => AlertDialog(
          title: const Text('CSV import failed'),
          content: Text('Could not import CSV: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _exportCsv() async {
    final ctx = context;
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Export passwords to CSV'),
        content: const Text(
          'CSV export is not encrypted. Share it only if you trust the target.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Export'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!ctx.mounted) return;

    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        title: Text('Exporting CSV'),
        content: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Please wait...'),
          ],
        ),
      ),
    );

    try {
      ref.read(autoLockProvider.notifier).suspendAutoLock();
      try {
        final service = CsvExportService(repo: ref.read(credentialRepoProvider));
        final file = await service.exportPasswordsCsv();
        if (!ctx.mounted) return;
        Navigator.pop(ctx);
        await SharePlus.instance.share(
          ShareParams(files: [XFile(file.path)], text: 'IronVault CSV export'),
        );
      } finally {
        ref.read(autoLockProvider.notifier).resumeAutoLock();
      }
    } catch (e) {
      await CrashReporter.captureException(
        e,
        StackTrace.current,
        feature: 'import_export',
        action: 'export_csv',
      );
      if (!ctx.mounted) return;
      Navigator.pop(ctx);
      showDialog(
        context: ctx,
        builder: (_) => AlertDialog(
          title: const Text('CSV export failed'),
          content: Text('Could not export CSV: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void _openBackupSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Backups and Import',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Encrypted Backup',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                ListTile(
                  leading: const Icon(Icons.backup_outlined),
                  title: const Text('Create encrypted backup'),
                  subtitle: const Text('Save a protected backup file to share or store'),
                  onTap: () {
                    Navigator.pop(context);
                    _exportBackup();
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.download_for_offline_outlined),
                  title: const Text('Restore encrypted backup'),
                  subtitle: const Text('Import items from a protected backup file'),
                  onTap: () {
                    Navigator.pop(context);
                    _importBackup();
                  },
                ),
                const SizedBox(height: 10),
                const Text(
                  'CSV (Passwords)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                ListTile(
                  leading: const Icon(Icons.table_rows_outlined),
                  title: const Text('Export to CSV'),
                  subtitle: const Text('Export passwords as a plain-text CSV file'),
                  onTap: () {
                    Navigator.pop(context);
                    _exportCsv();
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.table_chart_outlined),
                  title: const Text('Import from CSV'),
                  subtitle: const Text('Import passwords from a plain-text CSV file'),
                  onTap: () {
                    Navigator.pop(context);
                    _importCsv();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _logout() async {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const PinUnlockScreen()),
      (route) => false,
    );
  }

  Future<void> _setupRecoveryKey() async {
    final confirmed = await AppReauthUtil.confirmIdentity(
      context,
      ref,
      reason: 'Confirm your identity to manage the recovery key',
    );
    if (!confirmed || !mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecoveryKeyScreen(
          allowManualGenerate: true,
          hasExistingKey: _hasRecoveryKey,
          trustedForReveal: true,
          doneLabel: 'Done',
          onDone: () => Navigator.pop(context),
        ),
      ),
    );

    if (mounted) setState(() => _hasRecoveryKey = true);
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isDarkTheme = themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: widget.showAppBar ? AppBar(title: const Text("Settings")) : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          const SizedBox(height: 4),

          _settingsHeader(context),

          _sectionTitle("Security"),

          _settingsTile(
            context,
            icon: Icons.vpn_key_outlined,
            title: "Recovery Key",
            subtitle: _hasRecoveryKey
                ? "Generate a new recovery key"
                : "Set up your recovery key",
            onTap: _setupRecoveryKey,
            trailing: const Icon(Icons.chevron_right),
          ),

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

          _autoLockSection(context, ref),
          _settingsTile(
            context,
            icon: Icons.backup_outlined,
            title: "Backups and Import",
            subtitle: "Export, restore, and move your data",
            onTap: _openBackupSheet,
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

          _switchTile(
            context,
            icon: Icons.copy_rounded,
            title: "Disable Clipboard Copy",
            subtitle: "Prevent copying sensitive data",
            value: _clipboardDisabled,
            onChanged: _toggleClipboardDisabled,
          ),

          const SizedBox(height: 20),
          _sectionTitle("More"),

          _settingsTile(
            context,
            icon: Icons.health_and_safety,
            title: "Password Health",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PasswordHealthScreen(),
                ),
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

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _settingsHeader(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.12),
                child: Icon(
                  Icons.shield_moon_outlined,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'IronVault',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Your vault is protected and ready.',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AboutScreen()),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.tips_and_updates_outlined,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Security tip: $_securityTip',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
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
        subtitle: subtitle == null ? null : Text(subtitle),
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

  Widget _autoLockSection(BuildContext context, WidgetRef ref) {
    final currentTimerLabel =
        _AutoLockSheet.options[_autoLockTimer] ?? 'Immediately';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.12),
              child: Icon(
                Icons.lock_clock,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            title: const Text("Auto-Lock"),
            subtitle: const Text(
              "Lock when the app is sent to the background",
            ),
            trailing: Switch(
              value: _lockOnSwitch,
              onChanged: _toggleLockOnSwitch,
            ),
          ),
          if (_lockOnSwitch) ...[
            Divider(
              height: 1,
              indent: 16,
              endIndent: 16,
              color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
            ),
            ListTile(
              leading: const SizedBox(width: 36),
              title: const Text("Lock timing"),
              subtitle: Text("After backgrounding: $currentTimerLabel"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final selected = await showModalBottomSheet<String>(
                  context: context,
                  builder: (_) => const _AutoLockSheet(),
                );
                if (selected != null && mounted) {
                  setState(() => _autoLockTimer = selected);
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}

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

        return Padding(
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
              const SizedBox(height: 8),
              Text(
                "This timer is used after the app goes to the background.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
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

                    Navigator.pop(context, key);
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
