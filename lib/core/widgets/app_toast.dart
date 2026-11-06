// SPDX-FileCopyrightText: 2025-2026 Rizwan Mulla
// SPDX-License-Identifier: GPL-3.0-only
import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

void showAppToast(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 2),
}) {
  final overlay = Overlay.of(context, rootOverlay: true);

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) {
      return Positioned(
        left: 16,
        right: 16,
        bottom: 90,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ),
      );
    },
  );

  overlay.insert(entry);
  Timer(duration, () => entry.remove());
}

void showAppToastWithAction(
  BuildContext context,
  String message, {
  required String actionLabel,
  required VoidCallback onAction,
  Duration duration = const Duration(seconds: 4),
}) {
  final overlay = Overlay.of(context, rootOverlay: true);

  late OverlayEntry entry;
  Timer? timer;
  entry = OverlayEntry(
    builder: (ctx) {
      return Positioned(
        left: 16,
        right: 16,
        bottom: MediaQuery.paddingOf(context).bottom + 40,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            decoration: BoxDecoration(
              color: AppThemeColors.surfaceMuted(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withValues(
                  alpha: 0.45,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.32),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    timer?.cancel();
                    entry.remove();
                    onAction();
                  },
                  child: Text(actionLabel),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  overlay.insert(entry);
  timer = Timer(duration, () {
    if (entry.mounted) entry.remove();
  });
}
