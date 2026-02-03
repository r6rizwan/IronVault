import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ironvault/core/theme/app_tokens.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String version = "";
  String buildNumber = "";

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      version = info.version;
      buildNumber = info.buildNumber;
    });
  }

  @override
  Widget build(BuildContext context) {
    // final textMuted = AppThemeColors.textMuted(context);
    return Scaffold(
      appBar: AppBar(title: const Text("About")),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.12),
                    child: Icon(
                      Icons.lock,
                      size: 36,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "IronVault",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            _infoTile(
              context,
              label: "Version",
              value: version.isEmpty ? "Loading..." : version,
            ),

            _infoTile(
              context,
              label: "Build Number",
              value: buildNumber.isEmpty ? "Loading..." : buildNumber,
            ),

            const SizedBox(height: 20),

            _infoTile(context, label: "Developer", value: "Rizwan Mulla"),

            const SizedBox(height: 20),

            _infoTile(
              context,
              label: "Description",
              value:
                  "A secure, modern, open-design password manager created for personal use. "
                  "All credentials are encrypted using AES-256 and stored locally.",
              multiline: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(
    BuildContext context, {
    required String label,
    required String value,
    bool multiline = false,
  }) {
    final textMuted = AppThemeColors.textMuted(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
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
          Text(label, style: TextStyle(fontSize: 14, color: textMuted)),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 16),
            maxLines: multiline ? null : 2,
            overflow: multiline ? null : TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
