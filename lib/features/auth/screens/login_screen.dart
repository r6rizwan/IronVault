// ignore_for_file: depend_on_referenced_packages, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:local_auth/local_auth.dart';
import 'package:password_manager/main.dart';

import '../../vault/screens/credential_list_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _pinController = TextEditingController();
  final LocalAuthentication _auth = LocalAuthentication();

  bool _loading = false;
  bool _obscurePin = true;
  bool _biometricsAvailable = false;
  bool _biometricsEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricStatus();
  }

  String _hashPin(String pin) {
    return sha256.convert(utf8.encode(pin)).toString();
  }

  Future<void> _checkBiometricStatus() async {
    final storage = ref.read(secureStorageProvider);

    final enabled = await storage.readValue("biometrics_enabled") ?? "false";
    _biometricsEnabled = enabled == "true";

    final canCheck = await _auth.canCheckBiometrics;
    final supported = await _auth.isDeviceSupported();

    setState(() {
      _biometricsAvailable = canCheck && supported && _biometricsEnabled;
    });

    if (_biometricsAvailable) {
      Future.delayed(const Duration(milliseconds: 500), _useBiometrics);
    }
  }

  Future<void> _useBiometrics() async {
    try {
      final success = await _auth.authenticate(
        localizedReason: "Unlock your vault",
        biometricOnly: true,
      );

      if (success && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CredentialListScreen()),
        );
      }
    } catch (_) {}
  }

  Future<void> _tryLogin() async {
    setState(() => _loading = true);

    final storage = ref.read(secureStorageProvider);
    final savedHash = await storage.readPinHash();

    final entered = _pinController.text.trim();
    final hash = _hashPin(entered);

    await Future.delayed(const Duration(milliseconds: 300));

    if (savedHash == hash) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const CredentialListScreen()),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Invalid PIN")));
    }

    setState(() => _loading = false);
  }

  Widget _pinField() {
    return TextField(
      controller: _pinController,
      obscureText: _obscurePin,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: "Enter PIN",
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
          icon: Icon(_obscurePin ? Icons.visibility : Icons.visibility_off),
          onPressed: () {
            setState(() => _obscurePin = !_obscurePin);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spacing = const SizedBox(height: 16);

    return Scaffold(
      appBar: AppBar(title: const Text("Unlock Vault"), elevation: 0),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),

              // Header Icon
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.blueAccent,
                child: const Icon(Icons.lock, size: 40, color: Colors.white),
              ),
              const SizedBox(height: 16),

              const Text(
                "Enter your Master PIN",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),

              Text(
                "This unlocks your encrypted vault.",
                style: TextStyle(color: Colors.grey.shade600),
              ),

              const SizedBox(height: 28),

              _pinField(),
              spacing,

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _tryLogin,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
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
                      : const Text("Unlock"),
                ),
              ),

              const SizedBox(height: 14),

              if (_biometricsAvailable)
                ElevatedButton.icon(
                  onPressed: _useBiometrics,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text("Use Biometrics"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
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
