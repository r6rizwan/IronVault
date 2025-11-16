import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../vault/screens/credential_list_screen.dart';

class BiometricUnlock extends ConsumerStatefulWidget {
  const BiometricUnlock({super.key});

  @override
  ConsumerState<BiometricUnlock> createState() => _BiometricUnlockState();
}

class _BiometricUnlockState extends ConsumerState<BiometricUnlock> {
  final LocalAuthentication _auth = LocalAuthentication();
  bool _checking = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkBiometricSupport();
  }

  Future<void> _checkBiometricSupport() async {
    try {
      bool canCheck = await _auth.canCheckBiometrics;
      bool isDeviceSupported = await _auth.isDeviceSupported();

      if (!canCheck || !isDeviceSupported) {
        setState(() {
          _checking = false;
          _error = "Biometrics not available on this device.";
        });
        return;
      }

      await _authenticate();
    } catch (e) {
      setState(() {
        _checking = false;
        _error = "Error: $e";
      });
    }
  }

  Future<void> _authenticate() async {
    try {
      // Pass named parameters directly — don't use AuthenticationOptions
      final success = await _auth.authenticate(
        localizedReason: "Unlock your vault",
        biometricOnly: true,
      );

      if (!mounted) return;

      if (success) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CredentialListScreen()),
        );
      } else {
        setState(() {
          _checking = false;
          _error = "Biometric authentication failed.";
        });
      }
    } catch (e) {
      setState(() {
        _checking = false;
        _error = "Error: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Biometric Unlock")),
      body: Center(
        child: _error != null
            ? Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.red),
              )
            : ElevatedButton(
                onPressed: _authenticate,
                child: const Text("Try Again"),
              ),
      ),
    );
  }
}
