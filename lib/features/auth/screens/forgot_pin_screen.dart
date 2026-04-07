import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ironvault/core/providers.dart';
import 'package:ironvault/core/utils/recovery_key.dart';
import 'package:ironvault/core/theme/app_tokens.dart';
import 'package:ironvault/core/widgets/blocking_loading_overlay.dart';
import 'package:ironvault/features/auth/screens/recovery_key_verify_screen.dart';
import 'package:ironvault/features/auth/screens/setup_pin_screen.dart';

class ForgotPinScreen extends ConsumerStatefulWidget {
  const ForgotPinScreen({super.key});

  @override
  ConsumerState<ForgotPinScreen> createState() => _ForgotPinScreenState();
}

class _ForgotPinScreenState extends ConsumerState<ForgotPinScreen> {
  static const _failedPinAttemptsKey = 'failed_pin_attempts';
  static const _pinCooldownUntilKey = 'pin_cooldown_until';

  bool _resetting = false;

  Future<void> _resetVault() async {
    if (_resetting) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset Vault'),
        content: const Text(
          'This will delete all vault data and reset your PIN. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _resetting = true);

    final storage = ref.read(secureStorageProvider);
    final db = ref.read(dbProvider);
    await db.delete(db.credentials).go();
    await storage.deleteMasterKey();
    await storage.deletePinHash();
    await storage.deleteRecoveryKeyHash();
    await RecoveryKeyUtil.clearPendingState(storage);
    await storage.deleteValue(_failedPinAttemptsKey);
    await storage.deleteValue(_pinCooldownUntilKey);

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const SetupMasterPinScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = AppThemeColors.text(context);
    final textMuted = AppThemeColors.textMuted(context);
    final bgGradient = LinearGradient(
      colors: isDark
          ? [const Color(0xFF0B1020), const Color(0xFF111D38)]
          : [const Color(0xFFEFF4FF), const Color(0xFFF8FBFF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    final size = MediaQuery.of(context).size;
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context);
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text('Forgot PIN'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: textColor,
        ),
        body: BlockingLoadingOverlay(
          isLoading: _resetting,
          message: 'Resetting your vault...',
          child: Stack(
            children: [
              Container(decoration: BoxDecoration(gradient: bgGradient)),
              Positioned(
                top: -90,
                right: -40,
                child: _GlowOrb(
                  size: size.width * 0.58,
                  color: const Color(0xFF7AA8FF).withValues(alpha: 0.30),
                ),
              ),
              Positioned(
                bottom: -130,
                left: -70,
                child: _GlowOrb(
                  size: size.width * 0.65,
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.18),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        'Choose a recovery option',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You can reset using a recovery key or wipe the vault.',
                        style: TextStyle(fontSize: 12, color: textMuted),
                      ),
                      const SizedBox(height: 16),
                      _OptionCard(
                        title: 'Use Recovery Key',
                        subtitle: 'Reset PIN without losing data',
                        icon: Icons.vpn_key_outlined,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RecoveryKeyVerifyScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      _OptionCard(
                        title: 'Reset Vault (Delete Data)',
                        subtitle: 'Clear all vault data and set a new PIN',
                        icon: Icons.delete_outline,
                        onTap: _resetVault,
                      ),
                    ],
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

class _OptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _OptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
              child: Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppThemeColors.textMuted(context),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color,
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
