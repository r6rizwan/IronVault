// SPDX-FileCopyrightText: 2025-2026 Rizwan Mulla
// SPDX-License-Identifier: GPL-3.0-only
import 'dart:io';

import 'package:ironvault/core/secure_storage.dart';
import 'package:ironvault/core/utils/recovery_key.dart';
import 'package:ironvault/data/db/app_db.dart';
import 'package:ironvault/data/repositories/category_repository.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class VaultWipeUtil {
  VaultWipeUtil._();

  static Future<void> wipe({
    required AppDb db,
    required SecureStorage storage,
  }) async {
    final documents = await getApplicationDocumentsDirectory();
    await for (final entity in documents.list()) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      final isAttachment = name.startsWith('scan_');
      final isPrivateExport =
          (name.startsWith('ironvault_backup_') && name.endsWith('.ivault')) ||
          (name.startsWith('ironvault_passwords_') && name.endsWith('.csv'));
      if (isAttachment || isPrivateExport) {
        await entity.delete();
      }
    }

    final importedScans = Directory(p.join(documents.path, 'imported_scans'));
    if (await importedScans.exists()) {
      await importedScans.delete(recursive: true);
    }

    await db.delete(db.credentials).go();
    await CategoryRepository.instance.clearAll();

    await storage.deleteRecoveryKeyHash();
    await RecoveryKeyUtil.clearPendingState(storage);
    await storage.deleteValue('failed_pin_attempts');
    await storage.deleteValue('pin_cooldown_until');
    await storage.deleteValue('add_item_draft_v1');
    await storage.deleteMasterKey();
    await storage.deletePinHash();
  }
}
