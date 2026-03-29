// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:ironvault/core/providers.dart';
import 'package:ironvault/core/utils/pin_kdf.dart';
import 'package:ironvault/core/theme/app_tokens.dart';
import 'package:ironvault/core/widgets/app_toast.dart';

class ChangePinScreen extends ConsumerStatefulWidget {
  const ChangePinScreen({super.key});

  @override
  ConsumerState<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends ConsumerState<ChangePinScreen> {
  final int pinLength = 4;
  final List<TextEditingController> _oldPin = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<TextEditingController> _newPin = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<TextEditingController> _confirmPin = List.generate(
    4,
    (_) => TextEditingController(),
  );

  final List<FocusNode> _oldNodes = List.generate(4, (_) => FocusNode());
  final List<FocusNode> _newNodes = List.generate(4, (_) => FocusNode());
  final List<FocusNode> _confirmNodes = List.generate(4, (_) => FocusNode());

  bool _loading = false;
  bool _oldPinVerified = false;

  void _showMessage(String text) {
    showAppToast(context, text);
  }

  String _collect(List<TextEditingController> list) {
    return list.map((c) => c.text).join();
  }

  Future<bool> _verifyOldPinValue(String oldPin) async {
    final storage = ref.read(secureStorageProvider);
    final savedHash = await storage.readPinHash();
    if (savedHash == null) {
      _showMessage("PIN not set.");
      return false;
    }

    var ok = false;
    if (savedHash.contains(r'$')) {
      ok = PinKdf.verifyPin(oldPin, savedHash);
    } else {
      final legacy = sha256.convert(utf8.encode(oldPin)).toString();
      ok = legacy == savedHash;
    }

    if (!ok) return false;

    if (!savedHash.contains(r'$')) {
      await storage.writePinHash(PinKdf.hashPin(oldPin));
    }

    return true;
  }

  Future<void> _verifyOldPin() async {
    final oldPin = _collect(_oldPin);
    if (oldPin.length < 4) {
      _showMessage("Enter your current 4-digit PIN.");
      return;
    }

    setState(() => _loading = true);
    final ok = await _verifyOldPinValue(oldPin);
    if (!mounted) return;

    if (!ok) {
      setState(() => _loading = false);
      for (final c in _oldPin) {
        c.clear();
      }
      _oldNodes.first.requestFocus();
      _showMessage("Incorrect old PIN.");
      return;
    }

    setState(() {
      _loading = false;
      _oldPinVerified = true;
    });
    _newNodes.first.requestFocus();
  }

  Future<void> _changePin() async {
    final oldPin = _collect(_oldPin);
    final newPin = _collect(_newPin);
    final confirmPin = _collect(_confirmPin);

    if (!_oldPinVerified) {
      await _verifyOldPin();
      return;
    }

    if (newPin.length < 4) {
      _showMessage("New PIN must be at least 4 digits.");
      return;
    }

    if (newPin != confirmPin) {
      _showMessage("New PINs do not match.");
      return;
    }

    setState(() => _loading = true);

    final ok = await _verifyOldPinValue(oldPin);
    if (!ok) {
      for (final c in _oldPin) {
        c.clear();
      }
      for (final c in _newPin) {
        c.clear();
      }
      for (final c in _confirmPin) {
        c.clear();
      }
      setState(() => _loading = false);
      _oldPinVerified = false;
      _showMessage("Incorrect old PIN.");
      _oldNodes.first.requestFocus();
      return;
    }

    // Save new PIN hash (PBKDF2)
    final storage = ref.read(secureStorageProvider);
    await storage.writePinHash(PinKdf.hashPin(newPin));

    setState(() => _loading = false);

    _showMessage("PIN updated successfully!");

    if (!mounted) return;
    Navigator.pop(context);
  }

  Widget _otpBox({
    required TextEditingController controller,
    required FocusNode node,
    required VoidCallback onNext,
    required VoidCallback onBack,
    bool readOnly = false,
  }) {
    return SizedBox(
      width: 56,
      child: TextField(
        controller: controller,
        focusNode: node,
        readOnly: readOnly,
        maxLength: 1,
        obscureText: true,
        obscuringCharacter: '•',
        enableSuggestions: false,
        autocorrect: false,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          counterText: "",
          filled: true,
          fillColor: Theme.of(context).inputDecorationTheme.fillColor,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade400, width: 1.4),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 1.8,
            ),
          ),
        ),
        cursorColor: Theme.of(context).colorScheme.primary,
        onChanged: (value) {
          if (readOnly) return;
          if (value.isEmpty) {
            onBack();
          } else {
            onNext();
          }
        },
      ),
    );
  }

  Widget _otpRow(
    List<TextEditingController> controllers,
    List<FocusNode> nodes,
    {bool readOnly = false}
  ) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: List.generate(pinLength, (i) {
        return _otpBox(
          controller: controllers[i],
          node: nodes[i],
          readOnly: readOnly,
          onNext: () {
            if (i < pinLength - 1) {
              nodes[i + 1].requestFocus();
            }
          },
          onBack: () {
            if (i > 0) {
              controllers[i - 1].clear();
              nodes[i - 1].requestFocus();
            }
          },
        );
      }),
    );
  }

  @override
  void dispose() {
    for (final c in _oldPin) {
      c.dispose();
    }
    for (final c in _newPin) {
      c.dispose();
    }
    for (final c in _confirmPin) {
      c.dispose();
    }
    for (final n in _oldNodes) {
      n.dispose();
    }
    for (final n in _newNodes) {
      n.dispose();
    }
    for (final n in _confirmNodes) {
      n.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = const SizedBox(height: 16);
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

    return Scaffold(
      appBar: AppBar(title: const Text("Change Master PIN")),
      body: Container(
        decoration: BoxDecoration(gradient: bgGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
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
                    CircleAvatar(
                      radius: 34,
                      backgroundColor:
                          Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                      child: Icon(
                        Icons.password,
                        size: 30,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Change your Master PIN",
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: textColor),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _oldPinVerified
                          ? "Enter and confirm your new 4-digit PIN."
                          : "Verify your current 4-digit PIN first.",
                      style: TextStyle(fontSize: 12, color: textMuted),
                    ),
                    const SizedBox(height: 24),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Old PIN",
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _otpRow(_oldPin, _oldNodes, readOnly: _oldPinVerified),

                    if (_oldPinVerified) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.verified_outlined,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "Current PIN verified",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      spacing,

                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "New PIN",
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _otpRow(_newPin, _newNodes),

                      spacing,

                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Confirm New PIN",
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _otpRow(_confirmPin, _confirmNodes),
                    ],

                    const SizedBox(height: 28),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _changePin,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                _oldPinVerified
                                    ? "Update PIN"
                                    : "Verify Current PIN",
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
