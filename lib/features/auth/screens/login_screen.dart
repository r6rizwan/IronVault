// ignore_for_file: depend_on_referenced_packages, deprecated_member_use, use_build_context_synchronously

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:ironvault/core/autolock/auto_lock_provider.dart';
import 'package:ironvault/core/providers.dart';
import '../../vault/screens/credential_list_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final LocalAuthentication auth = LocalAuthentication();

  // Four controllers / focus nodes for OTP style inputs
  final List<TextEditingController> _controllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());

  bool biometricEnabled = false;
  bool biometricAvailable = false;

  late AnimationController _shakeController;
  final int pinLength = 4;

  @override
  void initState() {
    super.initState();
    _initBiometrics();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    // Attach listeners to each controller to handle auto-advance / auto-submit
    for (var i = 0; i < pinLength; i++) {
      _controllers[i].addListener(() => _onDigitChanged(i));
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.removeListener(() {});
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _initBiometrics() async {
    final storage = ref.read(secureStorageProvider);
    biometricEnabled =
        (await storage.readValue("biometrics_enabled") ?? "false") == "true";
    biometricAvailable =
        await auth.canCheckBiometrics && await auth.isDeviceSupported();
    setState(() {});
  }

  String _getEnteredPin() {
    return _controllers.map((c) => c.text).join();
  }

  String hashPin(String pin) => sha256.convert(utf8.encode(pin)).toString();

  // Called when any digit changes
  void _onDigitChanged(int index) {
    final text = _controllers[index].text;
    if (text.length > 1) {
      // If user pasted multiple characters into a field, distribute them
      final paste = text;
      _distributePaste(paste, startIndex: index);
      return;
    }

    if (text.isNotEmpty) {
      // Move to next field if exists
      if (index + 1 < pinLength) {
        _focusNodes[index + 1].requestFocus();
      } else {
        // Last digit entered — attempt submit
        if (_getEnteredPin().length == pinLength) {
          _submitPin();
        }
      }
    }
    // If user cleared a field, keep focus here (backspace logic handled in RawKeyboard)
    setState(() {});
  }

  // If user pastes multiple digits, distribute correctly across fields
  void _distributePaste(String paste, {required int startIndex}) {
    final digits = paste.replaceAll(RegExp(r'[^0-9]'), '');
    for (var i = 0; i < digits.length && (startIndex + i) < pinLength; i++) {
      _controllers[startIndex + i].text = digits[i];
    }
    // move focus to end or submit
    final next = startIndex + digits.length;
    if (next < pinLength) {
      _focusNodes[next].requestFocus();
    } else {
      _focusNodes[pinLength - 1].requestFocus();
      if (_getEnteredPin().length == pinLength) {
        _submitPin();
      }
    }
  }

  Future<void> _submitPin() async {
    final pin = _getEnteredPin();
    final storage = ref.read(secureStorageProvider);
    final savedHash = await storage.readPinHash();

    if (hashPin(pin) == savedHash) {
      ref.read(autoLockProvider.notifier).unlock();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const CredentialListScreen()),
      );
    } else {
      // wrong PIN — shake + clear
      _playWrongPinAnimation();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Invalid PIN")));
      _clearAll();
    }
  }

  void _playWrongPinAnimation() {
    _shakeController.forward(from: 0.0);
  }

  void _clearAll() {
    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes[0].requestFocus();
    setState(() {});
  }

  Future<void> _useBiometrics() async {
    try {
      final ok = await auth.authenticate(
        localizedReason: "Unlock IronVault",
        biometricOnly: true,
      );
      if (!ok) return;
      ref.read(autoLockProvider.notifier).unlock();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const CredentialListScreen()),
      );
    } catch (_) {}
  }

  // Widget building helpers
  Widget _buildOtpField(int index) {
    return SizedBox(
      width: 58,
      child: RawKeyboardListener(
        focusNode: FocusNode(), // needed for backspace detection
        onKey: (ev) {
          if (ev is RawKeyDownEvent &&
              ev.logicalKey == LogicalKeyboardKey.backspace) {
            final text = _controllers[index].text;
            if (text.isEmpty && index > 0) {
              _focusNodes[index - 1].requestFocus();
              _controllers[index - 1].clear();
            }
          }
        },
        child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            letterSpacing: 4,
          ),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 1,
          decoration: InputDecoration(
            counterText: "",
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24, width: 2),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.blueAccent, width: 2.4),
            ),
            filled: false,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
          cursorColor: Colors.blueAccent,
          onTap: () {
            // selectAll is not necessary for single char; do nothing
          },
          onChanged: (v) {
            // handled by controller listeners; keep for safety
            if (v.length > 1) {
              _distributePaste(v, startIndex: index);
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const gradientStart = Color(0xFF0A0F1F);
    const gradientEnd = Color(0xFF1A2235);

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [gradientStart, gradientEnd],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 28),

                // App Logo (top) - replace with your Image.asset or similar
                // Keep it tappable / adaptive
                SizedBox(
                  height: 96,
                  child: Center(
                    child: Column(
                      children: [
                        // Replace with your actual logo widget
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.vpn_key,
                            color: Colors.blueAccent,
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 6),

                // Title
                const Text(
                  "Enter your PIN",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 26),

                // OTP fields with shake animation
                AnimatedBuilder(
                  animation: _shakeController,
                  builder: (context, child) {
                    final progress = _shakeController.value;
                    // small horizontal shake from -8..8 when animating
                    final offsetX = (progress > 0)
                        ? (8 * (1 - (progress * 2 - 1).abs())) // easing
                        : 0.0;
                    return Transform.translate(
                      offset: Offset(offsetX * (progress > 0.5 ? -1 : 1), 0),
                      child: child,
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      pinLength,
                      (i) => _buildOtpField(i),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Row: Forgot PIN (left) + empty spacer + (biometric centered below)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 34.0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () async {
                          // Provide an entrypoint for resetting PIN using biometrics
                          // We'll attempt biometric auth and then navigate to a "Reset PIN" flow.
                          // For now, reuse biometric logic: if biometric ok -> clear saved PIN and prompt flow elsewhere.
                          // You can replace this with your reset flow screen.
                          if (!biometricAvailable || !biometricEnabled) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Biometrics not available"),
                              ),
                            );
                            return;
                          }

                          try {
                            final ok = await auth.authenticate(
                              localizedReason: "Authenticate to reset PIN",
                              biometricOnly: true,
                            );
                            if (!ok) return;
                            // Here you should open a reset-pin screen / flow.
                            // For demo, we will clear stored pin hash so user can set a new one in your onboarding.
                            final storage = ref.read(secureStorageProvider);
                            await storage.deletePinHash();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("You can now set a new PIN"),
                              ),
                            );
                          } catch (_) {
                            // ignore
                          }
                        },
                        child: const Text(
                          "Forgot PIN?",
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Biometric button (centered)
                if (biometricAvailable && biometricEnabled)
                  Center(
                    child: GestureDetector(
                      onTap: _useBiometrics,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Colors.blueAccent.withOpacity(0.9),
                            width: 1.4,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.fingerprint_rounded,
                              color: Colors.blueAccent,
                            ),
                            SizedBox(width: 10),
                            Text(
                              "Use biometric",
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // small bottom spacing
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
