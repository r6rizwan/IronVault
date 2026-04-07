// ignore_for_file: depend_on_referenced_packages, use_build_context_synchronously

import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:ironvault/core/autolock/auto_lock_provider.dart';
import 'package:ironvault/core/navigation/global_nav.dart';
import 'package:ironvault/core/providers.dart';
import 'package:ironvault/core/secure_storage.dart';
import 'package:ironvault/core/theme/app_tokens.dart';
import 'package:ironvault/core/utils/pin_kdf.dart';
import 'package:ironvault/core/widgets/app_toast.dart';
import 'package:ironvault/core/widgets/blocking_loading_overlay.dart';
import 'package:ironvault/features/auth/screens/auth_choice_screen.dart';
import 'package:ironvault/features/auth/screens/forgot_pin_screen.dart';
import 'package:ironvault/features/navigation/app_scaffold.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  static const _failedPinAttemptsKey = 'failed_pin_attempts';
  static const _pinCooldownUntilKey = 'pin_cooldown_until';
  static const _pinLength = 4;

  final LocalAuthentication _auth = LocalAuthentication();
  late AnimationController _shakeController;
  final List<String> _pinDigits = List.filled(_pinLength, '');
  Timer? _cooldownTimer;
  bool _loading = false;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  Duration? _remainingCooldown;
  String? _inlineError;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _loadCooldownState();
    _checkBiometric();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    if (_shakeController.isAnimating) {
      _shakeController.stop();
    }
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometric() async {
    final storage = ref.read(secureStorageProvider);
    _biometricEnabled =
        (await storage.readValue('biometrics_enabled') ?? 'false') == 'true';

    final canCheck = await _auth.canCheckBiometrics;
    final supported = await _auth.isDeviceSupported();
    _biometricAvailable = canCheck && supported;

    if (!mounted) return;
    setState(() {});
  }

  bool get _isCooldownActive =>
      _remainingCooldown != null && _remainingCooldown!.inSeconds > 0;

  bool get _canUseBiometrics => _biometricEnabled && _biometricAvailable;

  String _collectPin() => _pinDigits.join();

  Future<void> _loadCooldownState() async {
    final storage = ref.read(secureStorageProvider);
    final rawUntil = await storage.readValue(_pinCooldownUntilKey);
    final until = DateTime.tryParse(rawUntil ?? '');

    if (until == null || !until.isAfter(DateTime.now())) {
      await storage.deleteValue(_pinCooldownUntilKey);
      if (!mounted) return;
      setState(() => _remainingCooldown = null);
      return;
    }

    _startCooldownTicker(until);
  }

  void _startCooldownTicker(DateTime until) {
    _cooldownTimer?.cancel();
    _updateCooldown(until);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateCooldown(until);
    });
  }

  void _updateCooldown(DateTime until) {
    final remaining = until.difference(DateTime.now());
    if (remaining.inSeconds <= 0) {
      _cooldownTimer?.cancel();
      _clearCooldownState();
      return;
    }

    if (!mounted) return;
    setState(() => _remainingCooldown = remaining);
  }

  Future<void> _clearCooldownState() async {
    final storage = ref.read(secureStorageProvider);
    await storage.deleteValue(_pinCooldownUntilKey);
    if (!mounted) return;
    setState(() => _remainingCooldown = null);
  }

  Future<void> _resetPinAttemptState(SecureStorage storage) async {
    await storage.deleteValue(_failedPinAttemptsKey);
    await storage.deleteValue(_pinCooldownUntilKey);
    _cooldownTimer?.cancel();
    if (!mounted) return;
    setState(() => _remainingCooldown = null);
  }

  Duration? _cooldownForFailures(int failures) {
    if (failures >= 10) return const Duration(minutes: 15);
    if (failures >= 8) return const Duration(minutes: 5);
    if (failures >= 5) return const Duration(seconds: 30);
    return null;
  }

  Future<void> _recordFailedAttempt(SecureStorage storage) async {
    final rawCount = await storage.readValue(_failedPinAttemptsKey);
    final failures = (int.tryParse(rawCount ?? '') ?? 0) + 1;
    await storage.writeValue(_failedPinAttemptsKey, failures.toString());

    final cooldown = _cooldownForFailures(failures);
    if (cooldown == null) return;

    final until = DateTime.now().add(cooldown);
    await storage.writeValue(_pinCooldownUntilKey, until.toIso8601String());
    _startCooldownTicker(until);
  }

  String _formatCooldown(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    if (minutes > 0) {
      return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
    }
    return '${seconds}s';
  }

  Future<bool> _verifyPin(
    String pin,
    String stored,
    SecureStorage storage,
  ) async {
    if (stored.contains(r'$')) {
      return PinKdf.verifyPin(pin, stored);
    }

    final legacyHash = sha256.convert(utf8.encode(pin)).toString();
    if (legacyHash == stored) {
      await storage.writePinHash(PinKdf.hashPin(pin));
      return true;
    }
    return false;
  }

  void _appendDigit(String digit) {
    if (_loading || _isCooldownActive) return;
    final nextIndex = _pinDigits.indexOf('');
    if (nextIndex == -1) return;

    setState(() {
      _pinDigits[nextIndex] = digit;
      _inlineError = null;
    });

    if (_collectPin().length == _pinLength) {
      _submitPin();
    }
  }

  void _deleteDigit() {
    if (_loading || _isCooldownActive) return;
    for (var i = _pinDigits.length - 1; i >= 0; i--) {
      if (_pinDigits[i].isNotEmpty) {
        setState(() {
          _pinDigits[i] = '';
          _inlineError = null;
        });
        break;
      }
    }
  }

  void _clearAll() {
    setState(() {
      for (var i = 0; i < _pinDigits.length; i++) {
        _pinDigits[i] = '';
      }
    });
  }

  void _playWrongPinAnimation() {
    if (!mounted) return;
    try {
      _shakeController.forward(from: 0.0);
    } catch (_) {}
  }

  Future<void> _submitPin() async {
    final pin = _collectPin();
    if (pin.length < _pinLength || _loading) return;

    if (_isCooldownActive) {
      if (mounted) {
        showAppToast(
          context,
          'Too many attempts. Try again in ${_formatCooldown(_remainingCooldown!)}.',
        );
      }
      return;
    }

    if (mounted) {
      setState(() => _loading = true);
    }

    final storage = ref.read(secureStorageProvider);
    final savedHash = await storage.readPinHash();
    if (savedHash == null) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }

    await Future.delayed(const Duration(milliseconds: 120));

    final ok = await _verifyPin(pin, savedHash, storage);
    if (ok) {
      await _resetPinAttemptState(storage);
      ref.read(autoLockProvider.notifier).unlock();
      await Future.delayed(const Duration(milliseconds: 60));

      if (!mounted) return;
      navKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AppScaffold()),
        (_) => false,
      );
      return;
    }

    await _recordFailedAttempt(storage);
    _playWrongPinAnimation();

    if (mounted) {
      final message = _isCooldownActive
          ? 'Too many attempts. Try again in ${_formatCooldown(_remainingCooldown!)}.'
          : 'Invalid PIN';
      setState(() => _inlineError = message);
      showAppToast(context, message);
    }

    _clearAll();
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _useBiometrics() async {
    final autoLock = ref.read(autoLockProvider.notifier);
    try {
      if (!_canUseBiometrics || _loading) return;

      setState(() => _inlineError = null);

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

      if (!ok) return;

      ref.read(autoLockProvider.notifier).unlock();
      await Future.delayed(const Duration(milliseconds: 60));

      navKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AppScaffold()),
        (_) => false,
      );
    } on PlatformException catch (e) {
      if (e.code == 'auth_in_progress' ||
          e.code == 'notAvailable' ||
          e.code == 'notEnrolled' ||
          e.code == 'lockedOut' ||
          e.code == 'permanentlyLockedOut') {
        if (mounted) {
          setState(
            () => _inlineError = 'Biometric unavailable. Try PIN instead.',
          );
        }
      }
    } catch (_) {}
  }

  void _goBackToWelcome() {
    navKey.currentState?.pushReplacement(
      MaterialPageRoute(
        builder: (_) => const AuthChoiceScreen(),
        settings: const RouteSettings(name: AuthChoiceScreen.routeName),
      ),
    );
  }

  Widget _pinBox(int index) {
    final value = _pinDigits[index];
    final filled = value.isNotEmpty;
    final hasError = _inlineError != null && !_isCooldownActive;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: hasError
            ? Theme.of(context).colorScheme.error
            : filled
            ? Colors.white.withValues(alpha: 0.92)
            : Colors.white.withValues(alpha: 0.16),
        boxShadow: filled
            ? [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.08),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
    );
  }

  Widget _keyButton({required Widget child, VoidCallback? onTap}) {
    final enabled = onTap != null && !_loading;
    return InkResponse(
      onTap: enabled ? onTap : null,
      radius: 26,
      splashColor: Colors.white.withValues(alpha: 0.08),
      highlightColor: Colors.white.withValues(alpha: 0.04),
      child: SizedBox(height: 44, child: Center(child: child)),
    );
  }

  List<Widget> _buildKeypadButtons(Color textColor) {
    final buttons = <Widget>[
      for (final digit in ['1', '2', '3', '4', '5', '6', '7', '8', '9'])
        _keyButton(
          onTap: () => _appendDigit(digit),
          child: Text(
            digit,
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.94),
            ),
          ),
        ),
    ];

    buttons.add(
      _canUseBiometrics
          ? _keyButton(
              onTap: _useBiometrics,
              child: Icon(
                Icons.fingerprint,
                size: 24,
                color: Colors.white.withValues(alpha: 0.72),
              ),
            )
          : const SizedBox.shrink(),
    );

    buttons.add(
      _keyButton(
        onTap: () => _appendDigit('0'),
        child: Text(
          '0',
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.94),
          ),
        ),
      ),
    );

    buttons.add(
      _keyButton(
        onTap: _deleteDigit,
        child: Icon(
          Icons.backspace_outlined,
          color: Colors.white.withValues(alpha: 0.72),
        ),
      ),
    );

    return buttons;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = AppThemeColors.text(context);
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
        _goBackToWelcome();
      },
      child: Scaffold(
        body: BlockingLoadingOverlay(
          isLoading: _loading,
          message: 'Unlocking your vault...',
          child: Stack(
            children: [
              Container(decoration: BoxDecoration(gradient: bgGradient)),
              Positioned(
                top: -120,
                right: -70,
                child: _GlowOrb(
                  size: size.width * 0.7,
                  color: const Color(0xFF7AA8FF).withValues(alpha: 0.30),
                ),
              ),
              Positioned(
                bottom: -120,
                left: -60,
                child: _GlowOrb(
                  size: size.width * 0.66,
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.18),
                ),
              ),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(28, 18, 28, 24),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: 320,
                            minHeight: constraints.maxHeight - 42,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: IconButton(
                                  onPressed: _goBackToWelcome,
                                  tooltip: 'Back',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: Icon(
                                    Icons.arrow_back_rounded,
                                    color: textColor,
                                  ),
                                ),
                              ),
                              const Spacer(flex: 2),
                              Image.asset(
                                'assets/icon/app_icon.png',
                                width: 56,
                                height: 56,
                              ),
                              const SizedBox(height: 44),
                              Text(
                                'Enter PIN',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.92,
                                      ),
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 280,
                                ),
                                child: Text(
                                  _isCooldownActive
                                      ? 'Too many attempts. Wait a moment, then try again.'
                                      : 'Use your 4-digit PIN to unlock your vault.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white.withValues(alpha: 0.54),
                                    height: 1.35,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 22),
                              if (_inlineError != null) ...[
                                Text(
                                  _inlineError!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 10),
                              ],
                              AnimatedBuilder(
                                animation: _shakeController,
                                builder: (context, child) {
                                  final progress = _shakeController.value;
                                  final offset = progress > 0
                                      ? (8 * (1 - (progress * 2 - 1).abs()))
                                      : 0.0;

                                  return Transform.translate(
                                    offset: Offset(
                                      offset * (progress > 0.5 ? -1 : 1),
                                      0,
                                    ),
                                    child: child,
                                  );
                                },
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(
                                    _pinLength,
                                    (index) => Padding(
                                      padding: EdgeInsets.only(
                                        right: index == _pinLength - 1 ? 0 : 18,
                                      ),
                                      child: _pinBox(index),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 34),
                              GridView.count(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisCount: 3,
                                mainAxisSpacing: 14,
                                crossAxisSpacing: 18,
                                childAspectRatio: 1.2,
                                children: _buildKeypadButtons(textColor),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: _loading
                                    ? null
                                    : () {
                                        navKey.currentState?.push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const ForgotPinScreen(),
                                          ),
                                        );
                                      },
                                child: const Text('Forgot PIN?'),
                              ),
                              const Spacer(flex: 2),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
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
            colors: [
              color,
              color.withValues(alpha: color.a * 0.42),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
