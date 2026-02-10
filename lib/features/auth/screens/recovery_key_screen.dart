import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:ironvault/core/constants.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ironvault/core/autolock/auto_lock_provider.dart';
import 'package:ironvault/core/providers.dart';
import 'package:ironvault/features/vault/screens/enable_biometrics_screen.dart';
import 'package:ironvault/core/theme/app_tokens.dart';
import 'package:ironvault/core/widgets/app_toast.dart';

class RecoveryKeyScreen extends ConsumerStatefulWidget {
  final String recoveryKey;
  final VoidCallback? onDone;
  final String doneLabel;

  const RecoveryKeyScreen({
    super.key,
    required this.recoveryKey,
    this.onDone,
    this.doneLabel = 'I have saved it',
  });

  @override
  ConsumerState<RecoveryKeyScreen> createState() => _RecoveryKeyScreenState();
}

class _RecoveryKeyScreenState extends ConsumerState<RecoveryKeyScreen> {
  Timer? _clipboardTimer;
  bool _clipboardDisabled = false;
  late final AutoLockController _autoLock;
  @override
  void initState() {
    super.initState();
    _autoLock = ref.read(autoLockProvider.notifier);
    _autoLock.suspendAutoLock();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final storage = ref.read(secureStorageProvider);
    _clipboardDisabled =
        (await storage.readValue('disable_clipboard_copy') ?? 'false') == 'true';
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _clipboardTimer?.cancel();
    _autoLock.resumeAutoLock();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textMuted = AppThemeColors.textMuted(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Recovery Key')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Save this key somewhere safe.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'You can use it to reset your PIN without losing data.',
              style: TextStyle(fontSize: 12, color: textMuted),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.recoveryKey,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  if (!_clipboardDisabled)
                    IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: widget.recoveryKey),
                        );
                        _clipboardTimer?.cancel();
                        _clipboardTimer = Timer(
                          Duration(seconds: AppConstants.clipboardClearSeconds),
                          () async {
                            final data = await Clipboard.getData('text/plain');
                            if (data?.text == widget.recoveryKey) {
                              await Clipboard.setData(
                                const ClipboardData(text: ''),
                              );
                            }
                          },
                        );
                        if (context.mounted) {
                          showAppToast(context, 'Recovery key copied');
                        }
                      },
                    ),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (widget.onDone != null) {
                    widget.onDone!();
                    return;
                  }
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EnableBiometricsScreen(),
                    ),
                  );
                },
                child: Text(widget.doneLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
