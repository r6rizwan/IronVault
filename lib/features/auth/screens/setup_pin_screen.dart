// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:password_manager/features/vault/screens/enable_biometrics_screen.dart';
import 'package:password_manager/main.dart';

class SetupMasterPinScreen extends ConsumerStatefulWidget {
  const SetupMasterPinScreen({super.key});

  @override
  ConsumerState<SetupMasterPinScreen> createState() =>
      _SetupMasterPinScreenState();
}

class _SetupMasterPinScreenState extends ConsumerState<SetupMasterPinScreen> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _loading = false;
  bool _obscure1 = true;
  bool _obscure2 = true;

  String _hashPin(String pin) {
    return sha256.convert(utf8.encode(pin)).toString();
  }

  void _show(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _savePin() async {
    final pin = _pinController.text.trim();
    final confirm = _confirmController.text.trim();

    if (pin.length < 4) {
      _show("PIN must be at least 4 digits");
      return;
    }
    if (pin != confirm) {
      _show("PINs do not match");
      return;
    }

    setState(() => _loading = true);

    final storage = ref.read(secureStorageProvider);
    await storage.writePinHash(_hashPin(pin));

    setState(() => _loading = false);

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const EnableBiometricsScreen()),
    );
  }

  Widget _pinField({
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggle,
    required String label,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.grey.shade100,
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
      appBar: AppBar(title: const Text("Set Master PIN"), elevation: 0),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Icon
              Center(
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.blueAccent,
                  child: const Icon(Icons.lock, size: 40, color: Colors.white),
                ),
              ),
              const SizedBox(height: 16),

              const Center(
                child: Text(
                  "Create your Master PIN",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 6),

              Center(
                child: Text(
                  "This PIN protects your encrypted vault.",
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
              const SizedBox(height: 24),

              _pinField(
                controller: _pinController,
                obscure: _obscure1,
                onToggle: () => setState(() => _obscure1 = !_obscure1),
                label: "Enter PIN",
              ),
              spacing,

              _pinField(
                controller: _confirmController,
                obscure: _obscure2,
                onToggle: () => setState(() => _obscure2 = !_obscure2),
                label: "Confirm PIN",
              ),

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _savePin,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text("Continue"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
