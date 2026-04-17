// ignore_for_file: depend_on_referenced_packages, use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ironvault/core/navigation/global_nav.dart';
import 'package:ironvault/core/providers.dart';
import 'package:ironvault/core/utils/pin_kdf.dart';
import 'package:ironvault/core/utils/encryption_util.dart';
import 'package:ironvault/features/vault/screens/enable_biometrics_screen.dart';
import 'package:ironvault/core/theme/app_tokens.dart';
import 'package:ironvault/core/utils/recovery_key.dart';
import 'package:ironvault/features/auth/screens/recovery_key_screen.dart';
import 'package:ironvault/core/widgets/app_toast.dart';
import 'package:ironvault/core/widgets/blocking_loading_overlay.dart';

class SetupMasterPinScreen extends ConsumerStatefulWidget {
  const SetupMasterPinScreen({super.key});

  @override
  ConsumerState<SetupMasterPinScreen> createState() =>
      _SetupMasterPinScreenState();
}

class _SetupMasterPinScreenState extends ConsumerState<SetupMasterPinScreen> {
  final int pinLength = 4;

  final List<TextEditingController> _pin = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<TextEditingController> _confirm = List.generate(
    4,
    (_) => TextEditingController(),
  );

  final List<FocusNode> _pinNodes = List.generate(4, (_) => FocusNode());
  final List<FocusNode> _confirmNodes = List.generate(4, (_) => FocusNode());

  bool _loading = false;
  bool _obscurePin = true;

  bool get _canContinue =>
      _collect(_pin).length == pinLength &&
      _collect(_confirm).length == pinLength;

  void _showMsg(String msg) {
    showAppToast(context, msg);
  }

  String _collect(List<TextEditingController> list) {
    return list.map((c) => c.text).join();
  }

  Future<void> _savePin() async {
    final pin = _collect(_pin);
    final confirm = _collect(_confirm);

    if (pin.length < 4 || confirm.length < 4) {
      _showMsg("Please enter all 4 digits");
      return;
    }

    if (pin != confirm) {
      _showMsg("PINs do not match");
      return;
    }

    setState(() => _loading = true);

    final storage = ref.read(secureStorageProvider);
    final masterKey = await storage.readMasterKey();
    if (masterKey == null) {
      await storage.writeMasterKey(EncryptionUtil.generateKeyBase64());
    }
    await storage.writePinHash(PinKdf.hashPin(pin));

    final existingRecovery = await storage.readRecoveryKeyHash();
    if (existingRecovery == null) {
      final key = RecoveryKeyUtil.generate();
      await storage.writeRecoveryKeyHash(RecoveryKeyUtil.hash(key));
      await RecoveryKeyUtil.storePendingKey(storage, key);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => RecoveryKeyScreen(
            recoveryKey: key,
            trustedForReveal: true,
            onDone: () {
              navKey.currentState?.pushReplacement(
                MaterialPageRoute(
                  builder: (_) => const EnableBiometricsScreen(),
                ),
              );
            },
          ),
        ),
      );
      return;
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const EnableBiometricsScreen()),
    );
  }

  Widget _otpBox({
    required TextEditingController controller,
    required FocusNode node,
    required VoidCallback onNext,
    required VoidCallback onBack,
  }) {
    return Focus(
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.backspace &&
            controller.text.isEmpty) {
          onBack();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: SizedBox(
        width: 56,
        child: TextField(
          controller: controller,
          focusNode: node,
          maxLength: 1,
          obscureText: _obscurePin,
          obscuringCharacter: '•',
          enableSuggestions: false,
          autocorrect: false,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            counterText: "",
            filled: true,
            fillColor: Theme.of(context).inputDecorationTheme.fillColor,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade400, width: 1.4),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 1.8,
              ),
            ),
          ),
          cursorColor: Theme.of(context).colorScheme.primary,
          onChanged: (value) {
            setState(() {});
            if (value.isEmpty) {
              onBack();
            } else {
              onNext();
            }
          },
        ),
      ),
    );
  }

  Widget _otpRow(
    List<TextEditingController> controllers,
    List<FocusNode> nodes, {
    FocusNode? nextGroupFirstNode,
  }) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: List.generate(pinLength, (i) {
        return _otpBox(
          controller: controllers[i],
          node: nodes[i],
          onNext: () {
            if (i < pinLength - 1) {
              nodes[i + 1].requestFocus();
            } else if (nextGroupFirstNode != null) {
              nextGroupFirstNode.requestFocus();
            }
          },
          onBack: () {
            if (i > 0) {
              controllers[i - 1].clear();
              nodes[i - 1].requestFocus();
              setState(() {});
            }
          },
        );
      }),
    );
  }

  @override
  void dispose() {
    for (final c in _pin) {
      c.dispose();
    }
    for (final c in _confirm) {
      c.dispose();
    }
    for (final n in _pinNodes) {
      n.dispose();
    }
    for (final n in _confirmNodes) {
      n.dispose();
    }
    super.dispose();
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

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Create Master PIN"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: textColor,
      ),
      body: BlockingLoadingOverlay(
        isLoading: _loading,
        message: 'Setting up your PIN...',
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
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
                  child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
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
                          mainAxisSize: MainAxisSize.min,
                          children: [
                          CircleAvatar(
                            radius: 34,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.12),
                            child: Icon(
                              Icons.lock,
                              size: 30,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Set a 4-digit Master PIN",
                            style: Theme.of(
                              context,
                            ).textTheme.titleMedium?.copyWith(color: textColor),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "This PIN will unlock your secure vault.",
                            style: TextStyle(fontSize: 12, color: textMuted),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () {
                                setState(() => _obscurePin = !_obscurePin);
                              },
                              icon: Icon(
                                _obscurePin
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 18,
                              ),
                              label: Text(
                                _obscurePin ? "Show PIN" : "Hide PIN",
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "Enter PIN",
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _otpRow(
                            _pin,
                            _pinNodes,
                            nextGroupFirstNode: _confirmNodes.first,
                          ),
                          const SizedBox(height: 20),

                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "Confirm PIN",
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _otpRow(_confirm, _confirmNodes),
                          const SizedBox(height: 24),

                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: (_loading || !_canContinue)
                                  ? null
                                  : _savePin,
                              child: _loading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text("Continue"),
                            ),
                          ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  ),
                ),
              ),
            ),
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
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}
