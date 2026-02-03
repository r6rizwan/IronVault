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
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor:
                    Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                child: Icon(
                  Icons.fingerprint,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _error ?? "Authenticate with biometrics",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _error != null ? Colors.red : null,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _authenticate,
                child: const Text("Try Again"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
