// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ironvault/features/auth/screens/auth_choice_screen.dart';
import 'package:local_auth/local_auth.dart';
import 'package:ironvault/core/autolock/auto_lock_provider.dart';
import 'package:ironvault/core/providers.dart';
import 'package:ironvault/core/theme/app_tokens.dart';

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

      if (kDebugMode) {
        debugPrint(
          '[BIOMETRIC] canCheck: $canCheck, isSupported: $isSupported',
        );
      }

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
      if (kDebugMode) {
        debugPrint('[BIOMETRIC] enrolled types: $enrolled');
      }

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

      if (kDebugMode) {
        debugPrint('[BIOMETRIC] authenticate result: $didAuthenticate');
      }

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
          MaterialPageRoute(builder: (_) => const AuthChoiceScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric authentication cancelled or failed.'),
          ),
        );
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[BIOMETRIC] error: $e\n$st');
      }
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
      MaterialPageRoute(builder: (_) => const AuthChoiceScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMuted = AppThemeColors.textMuted(context);
    final bgGradient = LinearGradient(
      colors: isDark
          ? [const Color(0xFF0B0F1A), const Color(0xFF121826)]
          : [const Color(0xFFF7FAFF), const Color(0xFFEAF2FF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Scaffold(
      appBar: AppBar(title: const Text("Biometric Unlock")),
      body: Container(
        decoration: BoxDecoration(gradient: bgGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
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
                      radius: 36,
                      backgroundColor:
                          Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                      child: Icon(
                        Icons.fingerprint,
                        size: 36,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Enable Quick Unlock",
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _supported
                          ? "Use fingerprint or face to access your vault."
                          : "Your device does not support biometrics.",
                      style: TextStyle(
                        fontSize: 12,
                        color: textMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    if (_supported)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _enableBiometrics,
                          child: const Text("Enable Biometrics"),
                        ),
                      ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _skip,
                      child: const Text("Skip for now"),
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
