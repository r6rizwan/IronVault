import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_update_service.dart';

class UpdatePrompt {
  static Future<void> show(
    BuildContext context,
    AppUpdateInfo info,
  ) async {
    final theme = Theme.of(context);
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) {
        final maxContentHeight = MediaQuery.of(context).size.height * 0.4;
        return AlertDialog(
          title: const Text('Update available'),
          content: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxContentHeight),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Version ${info.displayVersion} is ready.'),
                  if (info.releaseNotes.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      info.releaseNotes,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Not now'),
            ),
            ElevatedButton(
              onPressed: () async {
                final uri = Uri.parse(info.apkUrl);
                await launchUrl(uri, mode: LaunchMode.externalApplication);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }
}
