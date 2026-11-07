// SPDX-FileCopyrightText: 2025-2026 Rizwan Mulla
// SPDX-License-Identifier: GPL-3.0-only
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ironvault/core/providers.dart';
import 'package:ironvault/core/utils/app_reauth_util.dart';
import 'package:ironvault/core/utils/vault_wipe_util.dart';
import 'package:ironvault/core/widgets/app_toast.dart';
import 'package:ironvault/core/widgets/blocking_loading_overlay.dart';
import 'package:ironvault/features/auth/screens/setup_master_pin_screen.dart';
import 'package:ironvault/features/categories/providers/category_provider.dart';

class EraseVaultScreen extends ConsumerStatefulWidget {
  const EraseVaultScreen({super.key});

  @override
  ConsumerState<EraseVaultScreen> createState() => _EraseVaultScreenState();
}

class _EraseVaultScreenState extends ConsumerState<EraseVaultScreen> {
  final _pinController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _busy = false;

  bool get _canErase =>
      _pinController.text.length == 4 &&
      _confirmationController.text.trim().toUpperCase() == 'DELETE';

  @override
  void dispose() {
    _pinController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _eraseVault() async {
    if (_busy || !_canErase) return;
    setState(() => _busy = true);

    final pinConfirmed = await AppReauthUtil.verifyMasterPin(
      ref,
      _pinController.text,
    );
    if (!mounted) return;
    if (!pinConfirmed) {
      setState(() => _busy = false);
      showAppToast(
        context,
        'Master PIN is invalid or temporarily locked. Vault was not erased.',
      );
      return;
    }

    try {
      await VaultWipeUtil.wipe(
        db: ref.read(dbProvider),
        storage: ref.read(secureStorageProvider),
      );
      ref.invalidate(categoryListProvider);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const SetupMasterPinScreen()),
        (_) => false,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      showAppToast(
        context,
        'Wipe did not finish. Some data may already be erased; retry to complete.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final danger = Theme.of(context).colorScheme.error;
    return Scaffold(
      appBar: AppBar(title: const Text('Erase Vault Data')),
      body: BlockingLoadingOverlay(
        isLoading: _busy,
        message: 'Permanently erasing vault data...',
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Icon(Icons.warning_amber_rounded, color: danger, size: 48),
            const SizedBox(height: 12),
            Text(
              'This cannot be undone',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: danger,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Erasing removes all saved items, document attachments, custom categories, drafts, private app exports, the recovery key, and encryption keys. IronVault cannot restore this data afterward.',
            ),
            const SizedBox(height: 20),
            const Text(
              'Exported copies in Downloads, cloud storage, or other locations are not deleted and may still be used to restore data. App preferences, such as theme and auto-lock settings, will remain unchanged.',
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              decoration: const InputDecoration(
                labelText: 'Master PIN',
                helperText: 'Required to authorize erasing this vault.',
                counterText: '',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmationController,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Type DELETE to continue',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _canErase && !_busy ? _eraseVault : null,
                style: FilledButton.styleFrom(
                  backgroundColor: danger,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: const Icon(Icons.delete_forever),
                label: const Text('Erase Vault Permanently'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
