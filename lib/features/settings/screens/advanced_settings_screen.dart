import 'package:flutter/material.dart';
import 'package:ironvault/core/update/app_update_service.dart';
import 'package:ironvault/core/update/update_prompt.dart';
import 'package:ironvault/features/settings/screens/about_screen.dart';
import 'package:ironvault/features/settings/screens/security_tips_screen.dart';
import 'package:ironvault/features/vault/screens/password_health_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class AdvancedSettingsScreen extends StatelessWidget {
  const AdvancedSettingsScreen({super.key});

  Future<void> _checkForUpdates(BuildContext context) async {
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return const AlertDialog(
          title: Text('Checking for updates'),
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
        );
      },
    );

    final info = await AppUpdateService().checkForUpdate();
    if (!context.mounted) return;
    Navigator.pop(context);

    if (info == null) {
      showDialog(
        context: context,
        builder: (_) {
          return AlertDialog(
            title: const Text('No update found'),
            content: const Text('You already have the latest version.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
      return;
    }

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Found one update'),
          content: Text('Version ${info.latestVersion} is available.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Not now'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                UpdatePrompt.show(context, info);
              },
              child: const Text('Download'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Advanced Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle('Security Tools'),
          _settingsTile(
            context,
            icon: Icons.health_and_safety,
            title: 'Password Health',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PasswordHealthScreen()),
              );
            },
          ),
          _settingsTile(
            context,
            icon: Icons.security,
            title: 'Security Tips',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SecurityTipsScreen()),
              );
            },
          ),
          const SizedBox(height: 20),
          _sectionTitle('App'),
          _settingsTile(
            context,
            icon: Icons.system_update_alt,
            title: 'Check for Updates',
            onTap: () => _checkForUpdates(context),
          ),
          _settingsTile(
            context,
            icon: Icons.info_outline,
            title: 'About',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AboutScreen()),
              );
            },
          ),
          // Migration Log intentionally hidden from end users.
          // If needed later, re-add the Migration Log tile here.
          const SizedBox(height: 20),
          _sectionTitle('Support'),
          _settingsTile(
            context,
            icon: Icons.bug_report_outlined,
            title: 'Report an Issue',
            onTap: () async {
              const url = 'https://github.com/r6rizwan/Password-Manager/issues';
              final uri = Uri.parse(url);
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
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

  Widget _settingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    VoidCallback? onTap,
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
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
