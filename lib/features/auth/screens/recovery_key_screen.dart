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
import 'package:ironvault/core/widgets/blocking_loading_overlay.dart';

class RecoveryKeyScreen extends ConsumerStatefulWidget {
  final String? recoveryKey;
  final VoidCallback? onDone;
  final String doneLabel;
  final bool trustedForReveal;
  final bool allowManualGenerate;
  final bool hasExistingKey;

  const RecoveryKeyScreen({
    super.key,
    this.recoveryKey,
    this.onDone,
    this.doneLabel = 'I have saved it',
    this.trustedForReveal = false,
    this.allowManualGenerate = false,
    this.hasExistingKey = true,
  });

  @override
  ConsumerState<RecoveryKeyScreen> createState() => _RecoveryKeyScreenState();
}

class _RecoveryKeyScreenState extends ConsumerState<RecoveryKeyScreen> {
  late String? _recoveryKey;
  bool _isRevealed = false;
  bool _confirming = false;
  bool _confirmedThisSession = false;
  String _busyMessage = 'Saving your recovery key confirmation...';

  @override
  void initState() {
    super.initState();
    _recoveryKey = widget.recoveryKey;
  }

  String get _maskedRecoveryKey {
    final key = _recoveryKey ?? '';
    return key.replaceAll(RegExp(r'[A-Z0-9]'), '•');
  }

  Future<void> _toggleRecoveryKeyVisibility() async {
    if (_recoveryKey == null) return;
    if (_isRevealed) {
      setState(() => _isRevealed = false);
      return;
    }

    if (widget.trustedForReveal) {
      setState(() => _isRevealed = true);
      return;
    }

    final autoLock = ref.read(autoLockProvider.notifier);
    autoLock.suspendAutoLock();
    bool didAuthenticate;
    try {
      didAuthenticate = await AppReauthUtil.confirmIdentity(
        context,
        ref,
        reason: 'Re-authenticate to reveal your recovery key',
      );
    } finally {
      autoLock.resumeAutoLock();
    }

    if (!mounted || !didAuthenticate) {
      if (mounted) {
        showAppToast(context, 'Verification required to reveal the key');
      }
      return;
    }

    setState(() => _isRevealed = true);
  }

  Future<void> _promptAndGenerateRecoveryKey() async {
    if (!mounted) return;

    final shouldGenerate = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Generate New Recovery Key?'),
        content: const Text(
          'This will replace your current recovery key. Your old recovery key will stop working, so make sure you save the new one before leaving this flow.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Generate'),
          ),
        ],
      ),
    );

    if (!mounted || shouldGenerate != true) return;

    setState(() {
      _busyMessage = 'Generating your new recovery key...';
      _confirming = true;
    });

    final storage = ref.read(secureStorageProvider);
    final key = RecoveryKeyUtil.generate();
    await storage.writeRecoveryKeyHash(RecoveryKeyUtil.hash(key));
    await RecoveryKeyUtil.storePendingKey(storage, key);

    if (!mounted) return;
    setState(() {
      _recoveryKey = key;
      _isRevealed = true;
      _confirmedThisSession = false;
      _confirming = false;
      _busyMessage = 'Saving your recovery key confirmation...';
    });
  }

  Future<void> _confirmSaved() async {
    if (_confirming || _recoveryKey == null) return;
    setState(() {
      _busyMessage = 'Saving your recovery key confirmation...';
      _confirming = true;
    });

    final storage = ref.read(secureStorageProvider);
    await RecoveryKeyUtil.markConfirmed(storage);

    if (!mounted) return;
    setState(() {
      _confirming = false;
      _confirmedThisSession = true;
    });

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

  Future<void> _handleBackAttempt() async {
    if (_recoveryKey == null) {
      Navigator.pop(context);
      return;
    }

    if (_confirmedThisSession) {
      Navigator.pop(context);
      return;
    }

    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Recovery Key Screen?'),
        content: const Text(
          'You have not confirmed saving this recovery key yet. If you leave now, you can return and review it later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (!mounted || leave != true) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = AppThemeColors.text(context);
    final textMuted = AppThemeColors.textMuted(context);
    final bgGradient = LinearGradient(
      colors: isDark
          ? [const Color(0xFF0B1020), const Color(0xFF111D38)]
          : [const Color(0xFFEFF4FF), const Color(0xFFF8FBFF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    final size = MediaQuery.of(context).size;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackAttempt();
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text('Recovery Key'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: textColor,
        ),
        body: BlockingLoadingOverlay(
          isLoading: _confirming,
          message: _busyMessage,
          child: Stack(
            children: [
              Container(decoration: BoxDecoration(gradient: bgGradient)),
              Positioned(
                top: -90,
                right: -40,
                child: _GlowOrb(
                  size: size.width * 0.58,
                  color: const Color(0xFF7AA8FF).withValues(alpha: 0.30),
                ),
              ),
              Positioned(
                bottom: -130,
                left: -70,
                child: _GlowOrb(
                  size: size.width * 0.65,
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.18),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Save this key somewhere safe.',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _recoveryKey != null
                            ? 'You can use it to reset your PIN without losing data.'
                            : widget.hasExistingKey
                                ? 'Generate a replacement key if you want to retire the current one.'
                                : 'Generate a recovery key so you can reset your PIN without losing data.',
                        style: TextStyle(fontSize: 12, color: textMuted),
                      ),
                      const SizedBox(height: 12),
                      if (_recoveryKey != null)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
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
                                          _recoveryKey!,
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
                        )
                      else
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            widget.hasExistingKey
                                ? 'Your current recovery key remains active until you manually generate a new one.'
                                : 'No recovery key has been generated for this device yet.',
                            style: TextStyle(fontSize: 13, color: textMuted, height: 1.4),
                          ),
                        ),
                      if (_recoveryKey == null && widget.allowManualGenerate) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _confirming ? null : _promptAndGenerateRecoveryKey,
                            child: Text(
                              widget.hasExistingKey
                                  ? 'Generate New Key'
                                  : 'Generate Recovery Key',
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Write this key down and store it somewhere safe.\nDo not screenshot or copy it.',
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.amber,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: (_confirming || _recoveryKey == null)
                              ? null
                              : _confirmSaved,
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}
