import 'package:flutter/material.dart';

class SecurityTipsScreen extends StatelessWidget {
  const SecurityTipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tips = [
      "Use unique passwords for every account.",
      "Avoid reusing passwords between websites.",
      "Enable two-factor authentication whenever possible.",
      "Never share your master PIN with anyone.",
      "Use long and complex passwords (12+ characters).",
      "Change passwords regularly, especially for important accounts.",
      "Keep your device updated with security patches.",
      "Do not store passwords in plain text or notes apps.",
      "Be cautious of phishing emails and fake login pages.",
      "Lock your vault when not using the app.",
    ];

    return Scaffold(
      appBar: AppBar(title: const Text("Security Tips")),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: tips.length,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tips[index],
                    style: const TextStyle(fontSize: 15, height: 1.4),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
