import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ironvault/core/autolock/auto_lock_provider.dart';
import 'package:ironvault/core/providers.dart';
import 'package:ironvault/core/utils/app_reauth_util.dart';
import 'package:ironvault/core/utils/recovery_key.dart';
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
  late final AutoLockController _autoLock;
  bool _isRevealed = false;
  bool _confirming = false;

  @override
  void initState() {
    super.initState();
    _autoLock = ref.read(autoLockProvider.notifier);
    _autoLock.suspendAutoLock();
  }

  @override
  void dispose() {
    _autoLock.resumeAutoLock();
    super.dispose();
  }

  String get _maskedRecoveryKey {
    return widget.recoveryKey.replaceAll(RegExp(r'[A-Z0-9]'), '•');
  }

  Future<void> _toggleRecoveryKeyVisibility() async {
    if (_isRevealed) {
      setState(() => _isRevealed = false);
      return;
    }

    final didAuthenticate = await AppReauthUtil.confirmIdentity(
      context,
      ref,
      reason: 'Re-authenticate to reveal your recovery key',
    );

    if (!mounted || !didAuthenticate) {
      if (mounted) {
        showAppToast(context, 'Verification required to reveal the key');
      }
      return;
    }

    setState(() => _isRevealed = true);
  }

  Future<void> _confirmSaved() async {
    if (_confirming) return;
    setState(() => _confirming = true);

    final storage = ref.read(secureStorageProvider);
    await RecoveryKeyUtil.markConfirmed(storage);

    if (!mounted) return;
    setState(() => _confirming = false);

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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              widget.recoveryKey,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          if (!_isRevealed)
                            Positioned.fill(
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                child: Container(
                                  color: Theme.of(context)
                                      .scaffoldBackgroundColor
                                      .withValues(alpha: 0.55),
                                  alignment: Alignment.center,
                                  child: Text(
                                    _maskedRecoveryKey,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1,
                                      color: AppThemeColors.text(context),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _isRevealed ? Icons.visibility_off : Icons.visibility,
                    ),
                    tooltip: _isRevealed ? 'Hide key' : 'Reveal key',
                    onPressed: _toggleRecoveryKeyVisibility,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Write this key down and store it somewhere safe.\nDo not screenshot or copy it.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.amber,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _confirming ? null : _confirmSaved,
                child: _confirming
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(widget.doneLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
