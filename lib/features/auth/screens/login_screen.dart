// lib/features/auth/screens/login_screen.dart
// ignore_for_file: depend_on_referenced_packages, use_build_context_synchronously, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ironvault/core/providers.dart';
import 'package:ironvault/core/secure_storage.dart';
import 'package:ironvault/features/navigation/app_scaffold.dart';
import 'package:ironvault/core/navigation/global_nav.dart';
import 'package:ironvault/core/autolock/auto_lock_provider.dart';
import 'package:ironvault/core/utils/pin_kdf.dart';
import 'package:ironvault/features/auth/screens/forgot_pin_screen.dart';
import 'package:ironvault/core/theme/app_tokens.dart';
import 'package:ironvault/core/widgets/app_toast.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  static const _failedPinAttemptsKey = 'failed_pin_attempts';
  static const _pinCooldownUntilKey = 'pin_cooldown_until';

  final int pinLength = 4;
  final List<TextEditingController> _pinCtrls = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _pinNodes = List.generate(4, (_) => FocusNode());

  // store listeners so we can remove them in dispose
  final List<VoidCallback> _ctrlListeners = [];

  late AnimationController _shakeController;
  Timer? _cooldownTimer;
  bool _loading = false;
  Duration? _remainingCooldown;
  String? _inlineError;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    // Attach listeners and keep references for proper disposal
    for (var i = 0; i < pinLength; i++) {
      void listener() => _onDigitChanged(i);
      _ctrlListeners.add(listener);
      _pinCtrls[i].addListener(listener);
    }

    _loadCooldownState();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();

    // remove listeners
    for (var i = 0; i < _pinCtrls.length; i++) {
      if (i < _ctrlListeners.length) {
        _pinCtrls[i].removeListener(_ctrlListeners[i]);
      }
      _pinCtrls[i].dispose();
    }

    for (final n in _pinNodes) {
      n.dispose();
    }

    // stop any running animation and dispose
    if (_shakeController.isAnimating) {
      _shakeController.stop();
    }
    _shakeController.dispose();

    super.dispose();
  }

  String _collectPin() => _pinCtrls.map((c) => c.text).join();

  bool get _isCooldownActive =>
      _remainingCooldown != null && _remainingCooldown!.inSeconds > 0;

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

    // Legacy SHA256 hash (no salt) — verify then upgrade to PBKDF2.
    final legacyHash = sha256.convert(utf8.encode(pin)).toString();
    if (legacyHash == stored) {
      await storage.writePinHash(PinKdf.hashPin(pin));
      return true;
    }
    return false;
  }

  void _onDigitChanged(int index) {
    final txt = _pinCtrls[index].text;

    if (txt.length > 1) {
      final digits = txt.replaceAll(RegExp(r'[^0-9]'), '');
      for (var i = 0; i < digits.length && index + i < pinLength; i++) {
        _pinCtrls[index + i].text = digits[i];
      }
      final next = index + digits.length;

      if (next < pinLength) {
        if (mounted) _pinNodes[next].requestFocus();
      } else {
        if (mounted) _pinNodes[pinLength - 1].requestFocus();
        if (_collectPin().length == pinLength) _submitPin();
      }
      return;
    }

    if (txt.isNotEmpty) {
      if (index + 1 < pinLength) {
        if (mounted) _pinNodes[index + 1].requestFocus();
      } else {
        if (_collectPin().length == pinLength) _submitPin();
      }
    }

    if (!mounted) return;
    if (_inlineError != null) {
      setState(() => _inlineError = null);
      return;
    }
    setState(() {});
  }

  Future<void> _submitPin() async {
    final pin = _collectPin();
    if (pin.length < pinLength) return;

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

    // small delay so digits render fully
    await Future.delayed(const Duration(milliseconds: 120));

    final ok = await _verifyPin(pin, savedHash, storage);
    if (ok) {
      await _resetPinAttemptState(storage);

      // unlock provider first
      ref.read(autoLockProvider.notifier).unlock();

      // allow state to propagate
      await Future.delayed(const Duration(milliseconds: 60));

      if (!mounted) return;

      // Navigate away and return immediately — do not call setState after this
      navKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AppScaffold()),
        (_) => false,
      );
      return;
    } else {
      await _recordFailedAttempt(storage);

      // wrong PIN — animate + clear
      _playWrongPinAnimation();

      if (mounted) {
        final message = _isCooldownActive
            ? 'Too many attempts. Try again in ${_formatCooldown(_remainingCooldown!)}.'
            : 'Invalid PIN';
        setState(() => _inlineError = message);
        showAppToast(context, message);
      }

      _clearAll();
    }

    // make sure widget still mounted before updating loading state
    if (!mounted) return;
    setState(() => _loading = false);
  }

  void _clearAll() {
    for (final c in _pinCtrls) {
      c.clear();
    }
    if (mounted) {
      _pinNodes[0].requestFocus();
      setState(() {});
    }
  }

  void _playWrongPinAnimation() {
    if (!mounted) return;
    // guard in case controller disposed
    try {
      _shakeController.forward(from: 0.0);
    } catch (_) {
      // ignore if disposed
    }
  }

  Widget _otpBox({required int index}) {
    final filled = _pinCtrls[index].text.isNotEmpty;
    final hasError = _inlineError != null && !_isCooldownActive;

    return SizedBox(
      width: 56,
      child: RawKeyboardListener(
        focusNode: FocusNode(),
        onKey: (ev) {
          if (ev is RawKeyDownEvent &&
              ev.logicalKey == LogicalKeyboardKey.backspace) {
            if (_pinCtrls[index].text.isEmpty && index > 0) {
              _pinCtrls[index - 1].clear();
              if (mounted) _pinNodes[index - 1].requestFocus();
            }
          }
        },
        child: TextField(
          controller: _pinCtrls[index],
          focusNode: _pinNodes[index],
          readOnly: _isCooldownActive,
          maxLength: 1,
          obscureText: true,
          obscuringCharacter: '•',
          enableSuggestions: false,
          autocorrect: false,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
          decoration: InputDecoration(
            counterText: "",
            filled: true,
            fillColor: Theme.of(context).inputDecorationTheme.fillColor,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: hasError
                    ? Theme.of(context).colorScheme.error
                    : filled
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.shade400,
                width: 1.4,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: hasError
                    ? Theme.of(context).colorScheme.error
                    : Colors.blueAccent,
                width: 1.8,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
          cursorColor: Colors.blueAccent,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = AppThemeColors.text(context);
    final textMuted = AppThemeColors.textMuted(context);
    final bgGradient = LinearGradient(
      colors: isDark
          ? [const Color(0xFF0B0F1A), const Color(0xFF121826)]
          : [const Color(0xFFF7FAFF), const Color(0xFFEAF2FF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        navKey.currentState?.pop();
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(gradient: bgGradient),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 32,
                ),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 4),
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.12),
                        child: Icon(
                          Icons.lock_outline,
                          color: Theme.of(context).colorScheme.primary,
                          size: 26,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Enter your PIN",
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(color: textColor),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isCooldownActive
                            ? "Try again in ${_formatCooldown(_remainingCooldown!)}"
                            : "Unlock IronVault",
                        style: TextStyle(fontSize: 12, color: textMuted),
                      ),
                      if (_inlineError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _inlineError!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),

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
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 12,
                          runSpacing: 12,
                          children: List.generate(pinLength, (i) {
                            return _otpBox(index: i);
                          }),
                        ),
                      ),

                      const SizedBox(height: 20),

                      Row(
                        children: [
                          TextButton(
                            onPressed: () {
                              navKey.currentState?.push(
                                MaterialPageRoute(
                                  builder: (_) => const ForgotPinScreen(),
                                ),
                              );
                            },
                            child: const Text("Forgot PIN?"),
                          ),
                          const Spacer(),
                        ],
                      ),

                      if (_loading) const CircularProgressIndicator(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
