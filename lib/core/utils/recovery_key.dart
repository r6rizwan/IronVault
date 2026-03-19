import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:ironvault/core/secure_storage.dart';
import 'package:ironvault/core/utils/encryption_util.dart';

class RecoveryKeyUtil {
  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const _pendingRecoveryKeyKey = 'pending_recovery_key';
  static const _recoveryKeyConfirmedKey = 'recovery_key_confirmed';

  static String generate() {
    final rnd = Random.secure();
    final parts = List.generate(4, (_) {
      return List.generate(4, (_) => _alphabet[rnd.nextInt(_alphabet.length)])
          .join();
    });
    return parts.join('-');
  }

  static String hash(String key) {
    return sha256.convert(utf8.encode(key)).toString();
  }

  static Future<void> storePendingKey(
    SecureStorage storage,
    String recoveryKey,
  ) async {
    final masterKey = await storage.readMasterKey();
    if (masterKey == null) {
      throw StateError('Master key missing while storing recovery key');
    }

    final encrypted = EncryptionUtil.encrypt(recoveryKey, masterKey);
    await storage.writeValue(_pendingRecoveryKeyKey, encrypted);
    await storage.writeValue(_recoveryKeyConfirmedKey, 'false');
  }

  static Future<String?> readPendingKey(SecureStorage storage) async {
    final encrypted = await storage.readValue(_pendingRecoveryKeyKey);
    final masterKey = await storage.readMasterKey();
    if (encrypted == null || encrypted.isEmpty || masterKey == null) {
      return null;
    }

    try {
      return EncryptionUtil.decrypt(encrypted, masterKey);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> isConfirmed(SecureStorage storage) async {
    return (await storage.readValue(_recoveryKeyConfirmedKey) ?? 'true') ==
        'true';
  }

  static Future<void> markConfirmed(SecureStorage storage) async {
    await storage.writeValue(_recoveryKeyConfirmedKey, 'true');
    await storage.deleteValue(_pendingRecoveryKeyKey);
  }

  static Future<void> clearPendingState(SecureStorage storage) async {
    await storage.deleteValue(_pendingRecoveryKeyKey);
    await storage.deleteValue(_recoveryKeyConfirmedKey);
  }
}
