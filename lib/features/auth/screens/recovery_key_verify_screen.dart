import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ironvault/core/theme/app_tokens.dart';
import 'package:ironvault/core/providers.dart';
import 'package:ironvault/core/utils/recovery_key.dart';
import 'package:ironvault/features/auth/screens/reset_pin_screen.dart';

class RecoveryKeyVerifyScreen extends ConsumerStatefulWidget {
  const RecoveryKeyVerifyScreen({super.key});

  @override
  ConsumerState<RecoveryKeyVerifyScreen> createState() =>
      _RecoveryKeyVerifyScreenState();
}

class _RecoveryKeyVerifyScreenState
    extends ConsumerState<RecoveryKeyVerifyScreen> {
  static const _formattedRecoveryKeyLength = 19;
  final TextEditingController _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final input = _controller.text.trim().toUpperCase();
    final stored = await ref.read(secureStorageProvider).readRecoveryKeyHash();
    if (stored == null) {
      setState(() => _error = 'No recovery key found on this device.');
      return;
    }
    if (RecoveryKeyUtil.hash(input) != stored) {
      setState(() => _error = 'Invalid recovery key.');
      return;
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ResetPinScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isComplete =
        _controller.text.trim().length == _formattedRecoveryKeyLength;
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

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Use Recovery Key'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: textColor,
      ),
      body: Stack(
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
                    'Enter your recovery key',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Use the key you saved when you first set up IronVault.',
                    style: TextStyle(fontSize: 12, color: textMuted),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _controller,
                    keyboardType: TextInputType.visiblePassword,
                    textCapitalization: TextCapitalization.characters,
                    autocorrect: false,
                    enableSuggestions: false,
                    inputFormatters: const [_RecoveryKeyInputFormatter()],
                    onChanged: (_) {
                      if (_error != null) {
                        setState(() => _error = null);
                      } else {
                        setState(() {});
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'XXXX-XXXX-XXXX-XXXX',
                      errorText: _error,
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isComplete ? _verify : null,
                      child: const Text('Continue'),
                    ),
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

class _RecoveryKeyInputFormatter extends TextInputFormatter {
  const _RecoveryKeyInputFormatter();

  static const _groupSize = 4;
  static const _groupCount = 4;
  static const _maxRawLength = _groupSize * _groupCount;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '')
        .characters
        .take(_maxRawLength)
        .toList()
        .join();

    final buffer = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      if (i > 0 && i % _groupSize == 0) {
        buffer.write('-');
      }
      buffer.write(raw[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
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
