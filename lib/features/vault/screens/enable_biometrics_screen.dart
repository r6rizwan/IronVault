// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:ironvault/core/autolock/auto_lock_provider.dart';
import 'package:ironvault/core/providers.dart';
import '../../vault/screens/credential_list_screen.dart';

class EnableBiometricsScreen extends ConsumerStatefulWidget {
  const EnableBiometricsScreen({super.key});

  @override
  ConsumerState<EnableBiometricsScreen> createState() =>
      _EnableBiometricsScreenState();
}

class _EnableBiometricsScreenState
    extends ConsumerState<EnableBiometricsScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  bool _checking = true;
  bool _supported = false;

  @override
  void initState() {
    super.initState();
    _checkSupport();
  }

  Future<void> _checkSupport() async {
    final canCheck = await auth.canCheckBiometrics;
    final supported = await auth.isDeviceSupported();

    setState(() {
      _supported = canCheck && supported;
      _checking = false;
    });
  }

  // Replace _enableBiometrics() with this:
  Future<void> _enableBiometrics() async {
    try {
      // 1) Basic capability checks
      final bool canCheck = await auth.canCheckBiometrics;
      final bool isSupported = await auth.isDeviceSupported();

      debugPrint('[BIOMETRIC] canCheck: $canCheck, isSupported: $isSupported');

      if (!canCheck || !isSupported) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometrics not supported on this device.'),
          ),
        );
        return;
      }

      // 2) Are there enrolled biometrics (fingerprints / face) ?
      final List<BiometricType> enrolled = await auth.getAvailableBiometrics();
      debugPrint('[BIOMETRIC] enrolled types: $enrolled');

      if (enrolled.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No biometrics enrolled. Please enroll fingerprint/Face ID in device settings.',
            ),
          ),
        );
        return;
      }

      // 3) Try to authenticate using only widely supported parameters
      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'Confirm to enable biometric unlock for your vault',
        biometricOnly: true,
      );

      debugPrint('[BIOMETRIC] authenticate result: $didAuthenticate');

      if (!mounted) return;

      if (didAuthenticate) {
        // Save preference
        final storage = ref.read(secureStorageProvider);
        await storage.writeValue('biometrics_enabled', 'true');

        // 🔥 RESET AUTO-LOCK STATE
        ref.read(autoLockProvider.notifier).unlock();

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Biometrics enabled')));

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CredentialListScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric authentication cancelled or failed.'),
          ),
        );
      }
    } catch (e, st) {
      debugPrint('[BIOMETRIC] error: $e\n$st');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Biometric error: $e')));
    }
  }

  Future<void> _skip() async {
    final storage = ref.read(secureStorageProvider);
    await storage.writeValue("biometrics_enabled", "false");

    // 🔥 Reset auto-lock
    ref.read(autoLockProvider.notifier).unlock();

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const CredentialListScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Biometric Unlock"), elevation: 0),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // Header Icon
              CircleAvatar(
                radius: 45,
                backgroundColor: Colors.blueAccent,
                child: Icon(Icons.fingerprint, size: 50, color: Colors.white),
              ),

              const SizedBox(height: 20),

              const Text(
                "Enable Quick Unlock",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              Text(
                _supported
                    ? "Use your fingerprint or Face ID to quickly access your vault."
                    : "Your device does not support biometric authentication.",
                style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 30),

              // If biometrics supported
              if (_supported)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _enableBiometrics,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      "Enable Biometrics",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 12),

              // Skip button
              TextButton(
                onPressed: _skip,
                child: const Text(
                  "Skip for now",
                  style: TextStyle(fontSize: 16),
                ),
              ),

              const Spacer(),

              // Info footer
              Text(
                "You can always enable biometrics later in settings.",
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
