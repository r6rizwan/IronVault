// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import 'package:ironvault/core/autolock/auto_lock_provider.dart';
import 'package:ironvault/core/navigation/global_nav.dart';
import 'package:ironvault/core/providers.dart';
import 'package:ironvault/core/theme/app_tokens.dart';
import 'package:ironvault/features/auth/screens/login_screen.dart';
import 'package:ironvault/features/navigation/app_scaffold.dart';

class AuthChoiceScreen extends ConsumerStatefulWidget {
  static const String routeName = '/auth-choice';
  const AuthChoiceScreen({super.key});

  @override
  ConsumerState<AuthChoiceScreen> createState() => _AuthChoiceScreenState();
}

class _AuthChoiceScreenState extends ConsumerState<AuthChoiceScreen> {
  final LocalAuthentication _auth = LocalAuthentication();
  bool _checking = true;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  bool _unlocking = false;
  String? _error;
  DateTime? _lastBackPress;
  OverlayEntry? _exitToast;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    final storage = ref.read(secureStorageProvider);
    _biometricEnabled =
        (await storage.readValue('biometrics_enabled') ?? 'false') == 'true';

    final canCheck = await _auth.canCheckBiometrics;
    final supported = await _auth.isDeviceSupported();
    _biometricAvailable = canCheck && supported;

    if (!mounted) return;
    setState(() => _checking = false);
  }

  Future<void> _useBiometrics() async {
    final autoLock = ref.read(autoLockProvider.notifier);
    try {
      if (!_biometricEnabled || !_biometricAvailable || _unlocking) return;

      setState(() {
        _unlocking = true;
        _error = null;
      });

      autoLock.suspendAutoLock();
      bool ok;
      try {
        ok = await _auth.authenticate(
          localizedReason: 'Unlock IronVault',
          biometricOnly: true,
        );
      } finally {
        autoLock.resumeAutoLock();
      }

      if (!ok) {
        if (!mounted) return;
        setState(() => _unlocking = false);
        return;
      }

      ref.read(autoLockProvider.notifier).unlock();
      await Future.delayed(const Duration(milliseconds: 60));

      navKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AppScaffold()),
        (_) => false,
      );
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() {
          _unlocking = false;
          if (e.code == 'auth_in_progress' ||
              e.code == 'notAvailable' ||
              e.code == 'notEnrolled' ||
              e.code == 'lockedOut' ||
              e.code == 'permanentlyLockedOut') {
            _error = 'Biometric unavailable right now. Use your PIN instead.';
          }
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _unlocking = false);
    }
  }

  void _usePin() {
    if (_unlocking) return;
    navKey.currentState?.push(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = AppThemeColors.text(context);
    final textMuted = AppThemeColors.textMuted(context);
    final size = MediaQuery.of(context).size;

    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final biometricEnabled = _biometricEnabled && _biometricAvailable;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastBackPress == null ||
            now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
          _lastBackPress = now;
          _showExitToast(context);
          return;
        }
        SystemNavigator.pop();
      },
      child: Scaffold(
        body: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF0B1020), const Color(0xFF111D38)]
                      : [const Color(0xFFEFF4FF), const Color(0xFFF8FBFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
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
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.60),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: isDark ? 0.06 : 0.22),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'IronVault',
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  color: textColor,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(flex: 3),
                    Text(
                      'Welcome back',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            color: textColor,
                            fontWeight: FontWeight.w800,
                            height: 0.98,
                          ),
                    ),
                    const SizedBox(height: 14),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: Text(
                        'Your vault stays encrypted on this device. Unlock it when you are ready.',
                        style: TextStyle(
                          fontSize: 15,
                          color: textMuted,
                          height: 1.45,
                        ),
                      ),
                    ),
                    const Spacer(flex: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.0),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 30,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Icon(
                                  Icons.lock_rounded,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Unlock your vault',
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                            color: textColor,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      biometricEnabled
                                          ? 'Use your PIN or biometrics to continue.'
                                          : 'Use your master PIN to continue.',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: textMuted,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _usePin,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: const Text('Unlock Vault'),
                            ),
                          ),
                          if (biometricEnabled) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _useBiometrics,
                                icon: _unlocking
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.fingerprint),
                                label: Text(_unlocking ? 'Checking biometrics...' : 'Use biometrics'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 15),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                              ),
                            ),
                          ],
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Spacer(flex: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          size: 14,
                          color: textMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Secured on this device',
                          style: TextStyle(fontSize: 11, color: textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showExitToast(BuildContext context) {
    _exitToast?.remove();
    _exitToast = OverlayEntry(
      builder: (ctx) => Positioned(
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
            child: const Text('Press back again to exit'),
          ),
        ),
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_exitToast!);
    Future.delayed(const Duration(seconds: 2), () {
      _exitToast?.remove();
      _exitToast = null;
    });
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
            colors: [
              color,
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
