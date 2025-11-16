// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:password_manager/main.dart';

class ChangePinScreen extends ConsumerStatefulWidget {
  const ChangePinScreen({super.key});

  @override
  ConsumerState<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends ConsumerState<ChangePinScreen> {
  final _oldPinController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  bool _loading = false;
  bool _showOld = false;
  bool _showNew = false;
  bool _showConfirm = false;

  String _hashPin(String pin) {
    return sha256.convert(utf8.encode(pin)).toString();
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _changePin() async {
    final oldPin = _oldPinController.text.trim();
    final newPin = _newPinController.text.trim();
    final confirmPin = _confirmPinController.text.trim();

    if (newPin.length < 4) {
      _showMessage("New PIN must be at least 4 digits.");
      return;
    }

    if (newPin != confirmPin) {
      _showMessage("New PINs do not match.");
      return;
    }

    setState(() => _loading = true);

    final storage = ref.read(secureStorageProvider);
    final savedHash = await storage.readPinHash();

    // Validate old PIN
    if (_hashPin(oldPin) != savedHash) {
      setState(() => _loading = false);
      _showMessage("Incorrect old PIN.");
      return;
    }

    // Save new PIN hash
    await storage.writePinHash(_hashPin(newPin));

    setState(() => _loading = false);

    _showMessage("PIN updated successfully!");

    if (!mounted) return;
    Navigator.pop(context);
  }

  Widget _pinField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
          onPressed: onToggle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spacing = const SizedBox(height: 16);

    return Scaffold(
      appBar: AppBar(title: const Text("Change Master PIN")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const SizedBox(height: 10),

            _pinField(
              controller: _oldPinController,
              label: "Old PIN",
              obscure: !_showOld,
              onToggle: () => setState(() => _showOld = !_showOld),
            ),

            spacing,

            _pinField(
              controller: _newPinController,
              label: "New PIN",
              obscure: !_showNew,
              onToggle: () => setState(() => _showNew = !_showNew),
            ),

            spacing,

            _pinField(
              controller: _confirmPinController,
              label: "Confirm New PIN",
              obscure: !_showConfirm,
              onToggle: () => setState(() => _showConfirm = !_showConfirm),
            ),

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
                    : const Text("Update PIN"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
