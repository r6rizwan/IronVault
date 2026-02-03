// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import 'package:ironvault/core/autolock/auto_lock_provider.dart';
import 'package:ironvault/core/navigation/global_nav.dart';
import 'package:ironvault/core/providers.dart';
import 'package:ironvault/features/auth/screens/login_screen.dart';
import 'package:ironvault/features/navigation/app_scaffold.dart';
import 'package:ironvault/core/theme/app_tokens.dart';

class AuthChoiceScreen extends ConsumerStatefulWidget {
  const AuthChoiceScreen({super.key});

  @override
  ConsumerState<AuthChoiceScreen> createState() => _AuthChoiceScreenState();
}

class _AuthChoiceScreenState extends ConsumerState<AuthChoiceScreen> {
  final LocalAuthentication _auth = LocalAuthentication();
  bool _checking = true;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    final storage = ref.read(secureStorageProvider);
    _biometricEnabled =
        (await storage.readValue("biometrics_enabled") ?? "false") == "true";

    final canCheck = await _auth.canCheckBiometrics;
    final supported = await _auth.isDeviceSupported();
    _biometricAvailable = canCheck && supported;

    if (mounted) {
      setState(() => _checking = false);
    }
  }

  Future<void> _useBiometrics() async {
    try {
      if (!_biometricEnabled || !_biometricAvailable) return;

      final ok = await _auth.authenticate(
        localizedReason: "Unlock IronVault",
        biometricOnly: true,
      );

      if (!ok) return;

      ref.read(autoLockProvider.notifier).unlock();
      await Future.delayed(const Duration(milliseconds: 60));

      navKey.currentState?.pushReplacement(
        MaterialPageRoute(builder: (_) => const AppScaffold()),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _error = "Biometric error: $e");
      }
    }
  }

  void _usePin() {
    navKey.currentState?.pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = AppThemeColors.text(context);
    final textMuted = AppThemeColors.textMuted(context);

    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final biometricEnabled = _biometricEnabled && _biometricAvailable;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF0A1022), const Color(0xFF0F1B36)]
                    : [const Color(0xFFEFF4FF), const Color(0xFFF7FBFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(
            top: -80,
            right: -40,
            child: _GlowOrb(
              size: size.width * 0.55,
              color: const Color(0xFF7AA8FF).withValues(alpha: 0.35),
            ),
          ),
          Positioned(
            bottom: -120,
            left: -60,
            child: _GlowOrb(
              size: size.width * 0.6,
              color: const Color(0xFF38BDF8).withValues(alpha: 0.25),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? Colors.white10 : Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      "assets/icon/app_icon.png",
                      width: 46,
                      height: 46,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    "IronVault",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "How do you want to log in?",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: textMuted,
                    ),
                  ),
                  const SizedBox(height: 26),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 26,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Choose a method",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _ChoiceTile(
                          icon: Icons.lock_rounded,
                          label: "Use PIN",
                          description: "Quick access with your master PIN",
                          highlight: const Color(0xFF2563EB),
                          onTap: _usePin,
                        ),
                        const SizedBox(height: 12),
                        _ChoiceTile(
                          icon: Icons.fingerprint,
                          label: "Use biometrics",
                          description: biometricEnabled
                              ? "Fingerprint or face ID"
                              : "Not available on this device",
                          highlight: const Color(0xFF0EA5E9),
                          disabled: !biometricEnabled,
                          onTap: biometricEnabled ? _useBiometrics : null,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        size: 14,
                        color: textMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "Secured on this device",
                        style: TextStyle(
                          fontSize: 11,
                          color: textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color,
            color.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final Color highlight;
  final bool disabled;
  final VoidCallback? onTap;

  const _ChoiceTile({
    required this.icon,
    required this.label,
    required this.description,
    required this.highlight,
    required this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColorBase = AppThemeColors.text(context);
    final textMuted = AppThemeColors.textMuted(context);
    final iconBg = disabled
        ? (isDark ? Colors.white12 : Colors.grey.shade200)
        : highlight.withValues(alpha: 0.14);
    final textColor = disabled ? Colors.grey.shade500 : textColorBase;
    final subColor = disabled ? Colors.grey.shade400 : textMuted;

    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : const Color(0xFFF8FAFF),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            if (!disabled)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: iconBg,
              child: Icon(
                icon,
                color: disabled ? Colors.grey : highlight,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(fontSize: 12, color: subColor),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: disabled ? Colors.grey.shade400 : highlight,
            ),
          ],
        ),
      ),
    );
  }
}
