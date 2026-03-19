import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: const [
          _PolicySection(
            title: 'Overview',
            body:
                'IronVault is designed to store your vault data on your device. The app does not use cloud sync by default.',
          ),
          _PolicySection(
            title: 'What the App Stores',
            body:
                'The app stores vault items, app settings, and recovery-related information needed to help you unlock or restore access to your vault.',
          ),
          _PolicySection(
            title: 'How Your Data Is Used',
            body:
                'Your data is used only to provide vault features on your device, such as unlocking, viewing, editing, backup, restore, and search.',
          ),
          _PolicySection(
            title: 'Network Access',
            body:
                'IronVault may contact GitHub to check whether a newer app version is available. Reporting an issue opens an external browser page.',
          ),
          _PolicySection(
            title: 'Backups and Exports',
            body:
                'Encrypted backups can be created and restored by you. CSV exports are not encrypted, so they should be handled carefully and stored only in places you trust.',
          ),
          _PolicySection(
            title: 'Your Responsibility',
            body:
                'Keep your PIN, recovery key, backup password, and exported files safe. If you lose both your PIN and recovery key, your vault data may not be recoverable.',
          ),
        ],
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  const _PolicySection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
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
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(body, style: const TextStyle(fontSize: 13, height: 1.45)),
        ],
      ),
    );
  }
}
