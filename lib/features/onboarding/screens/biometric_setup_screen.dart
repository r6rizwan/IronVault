import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:ironvault/core/navigation/global_nav.dart';
import 'package:ironvault/core/providers.dart';
import '../../auth/screens/login_screen.dart';
import 'package:ironvault/core/theme/app_tokens.dart';

class BiometricSetupScreen extends ConsumerStatefulWidget {
  const BiometricSetupScreen({super.key});

  @override
  ConsumerState<BiometricSetupScreen> createState() =>
      _BiometricSetupScreenState();
}

class _BiometricSetupScreenState extends ConsumerState<BiometricSetupScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  bool _isLoading = false;

  Future<void> _enableBiometrics() async {
    setState(() => _isLoading = true);

    try {
      final didAuth = await auth.authenticate(
        localizedReason: "Enable biometric unlock for IronVault",
        biometricOnly: true,
      );

      if (didAuth) {
        final storage = ref.read(secureStorageProvider);
        await storage.writeValue("biometrics_enabled", "true");

        // Go to login screen after enabling biometrics
        navKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    } catch (_) {}

    setState(() => _isLoading = false);
  }

  void _skip() {
    // Skip biometric setup → go to login
    navKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final textColor = AppThemeColors.text(context);
    final textMuted = AppThemeColors.textMuted(context);

    return Scaffold(
      backgroundColor: t.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            children: [
              const SizedBox(height: 40),

              CircleAvatar(
                radius: 44,
                backgroundColor:
                    t.colorScheme.primary.withValues(alpha: 0.12),
                child: Icon(
                  Icons.fingerprint_rounded,
                  size: 44,
                  color: t.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 30),

              Text(
                "Enable Biometric Unlock",
                textAlign: TextAlign.center,
                style: t.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                "Use your fingerprint or face to quickly unlock IronVault.",
                textAlign: TextAlign.center,
                style: t.textTheme.bodyLarge?.copyWith(color: textMuted),
              ),

              const SizedBox(height: 40),

              // Enable biometrics button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _enableBiometrics,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          "Enable Biometrics",
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),

              const SizedBox(height: 14),

              // Skip
              TextButton(onPressed: _skip, child: const Text("Skip for now")),
            ],
          ),
        ),
      ),
    );
  }
}
