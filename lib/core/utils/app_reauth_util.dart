import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ironvault/core/providers.dart';
import 'package:ironvault/core/utils/pin_kdf.dart';
import 'package:local_auth/local_auth.dart';

class AppReauthUtil {
  AppReauthUtil._();

  static Future<bool> confirmIdentity(
    BuildContext context,
    WidgetRef ref, {
    required String reason,
  }) async {
    final auth = LocalAuthentication();
    var shouldFallbackToPin = true;

    try {
      final canCheck = await auth.canCheckBiometrics;
      final supported = await auth.isDeviceSupported();
      if (canCheck && supported) {
        final enrolled = await auth.getAvailableBiometrics();
        if (enrolled.isNotEmpty) {
          final ok = await auth.authenticate(
            localizedReason: reason,
            biometricOnly: true,
          );
          if (ok) return true;
          return false;
        }
      }
    } on PlatformException catch (error) {
      final code = error.code.toLowerCase();
      if (code == 'canceled' ||
          code == 'cancelled' ||
          code == 'user_canceled' ||
          code == 'system_canceled') {
        shouldFallbackToPin = false;
      }
    } catch (_) {}

    if (!context.mounted || !shouldFallbackToPin) return false;
    return _promptForPin(context, ref);
  }

  static Future<bool> _promptForPin(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _PinConfirmDialog(ref: ref),
    );
    return result == true;
  }

  static Future<bool> _verifyPin(
    String pin,
    String stored,
    WidgetRef ref,
  ) async {
    if (stored.contains(r'$')) {
      return PinKdf.verifyPin(pin, stored);
    }

    final legacyHash = sha256.convert(utf8.encode(pin)).toString();
    if (legacyHash != stored) return false;

    await ref.read(secureStorageProvider).writePinHash(PinKdf.hashPin(pin));
    return true;
  }
}

class _PinConfirmDialog extends ConsumerStatefulWidget {
  const _PinConfirmDialog({required this.ref});

  final WidgetRef ref;

  @override
  ConsumerState<_PinConfirmDialog> createState() => _PinConfirmDialogState();
}

class _PinConfirmDialogState extends ConsumerState<_PinConfirmDialog> {
  static const _pinLength = 4;

  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  late final List<FocusNode> _keyboardNodes;
  String? _error;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(_pinLength, (_) => TextEditingController());
    _focusNodes = List.generate(_pinLength, (_) => FocusNode());
    _keyboardNodes = List.generate(_pinLength, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    for (final node in _keyboardNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get _pin => _controllers.map((c) => c.text).join();

  void _onDigitChanged(int index) {
    final txt = _controllers[index].text;

    if (txt.length > 1) {
      final digits = txt.replaceAll(RegExp(r'[^0-9]'), '');
      for (var i = 0; i < digits.length && index + i < _pinLength; i++) {
        _controllers[index + i].text = digits[i];
      }

      final next = index + digits.length;
      if (next < _pinLength) {
        _focusNodes[next].requestFocus();
      } else {
        _focusNodes[_pinLength - 1].requestFocus();
        if (_pin.length == _pinLength) _confirm();
      }
      setState(() {});
      return;
    }

    if (txt.isNotEmpty) {
      if (index + 1 < _pinLength) {
        _focusNodes[index + 1].requestFocus();
      } else if (_pin.length == _pinLength) {
        _confirm();
      }
    }

    if (_error != null) {
      setState(() => _error = null);
    } else {
      setState(() {});
    }
  }

  void _clearPin() {
    for (final controller in _controllers) {
      controller.clear();
    }
    _focusNodes.first.requestFocus();
  }

  Future<void> _confirm() async {
    if (_submitting || _pin.length < _pinLength) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    final storage = widget.ref.read(secureStorageProvider);
    final stored = await storage.readPinHash();

    if (!mounted) return;

    if (stored == null) {
      setState(() {
        _submitting = false;
        _error = 'PIN not available.';
      });
      return;
    }

    final ok = await AppReauthUtil._verifyPin(_pin, stored, widget.ref);
    if (!mounted) return;

    if (!ok) {
      setState(() {
        _submitting = false;
        _error = 'Invalid PIN.';
      });
      _clearPin();
      return;
    }

    FocusScope.of(context).unfocus();
    Navigator.pop(context, true);
  }

  Widget _pinBox(int index) {
    final filled = _controllers[index].text.isNotEmpty;

    return SizedBox(
      width: 46,
      child: KeyboardListener(
        focusNode: _keyboardNodes[index],
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace) {
            if (_controllers[index].text.isEmpty && index > 0) {
              _controllers[index - 1].clear();
              _focusNodes[index - 1].requestFocus();
              setState(() {});
            }
          }
        },
        child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          maxLength: 1,
          autofocus: index == 0,
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
            counterText: '',
            filled: true,
            fillColor: Theme.of(context).inputDecorationTheme.fillColor,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: filled
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.shade400,
                width: 1.4,
              ),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: Colors.blueAccent, width: 1.8),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
          cursorColor: Colors.blueAccent,
          onChanged: (_) => _onDigitChanged(index),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirm with PIN'),
      content: SizedBox(
        width: 260,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter your 4-digit PIN to continue.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pinLength * 2 - 1, (i) {
                if (i.isOdd) return const SizedBox(width: 8);
                return _pinBox(i ~/ 2);
              }),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _submitting || _pin.length < _pinLength ? null : _confirm,
          child: Text(_submitting ? 'Checking...' : 'Confirm'),
        ),
      ],
    );
  }
}
