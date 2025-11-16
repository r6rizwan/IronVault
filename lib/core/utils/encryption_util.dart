import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart';

class EncryptionUtil {
  /// Generates a 32-byte AES key (Base64 encoded)
  static String generateKeyBase64() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(32, (_) => rnd.nextInt(256));
    return base64.encode(bytes);
  }

  /// Internal helper: Create AES encrypter from Base64 key
  static Encrypter _encrypterFromKey(String keyBase64) {
    final key = Key(base64.decode(keyBase64));
    return Encrypter(AES(key, mode: AESMode.gcm));
  }

  /// Encrypt text with AES-GCM.
  /// Result: Base64(iv + ciphertext)
  static String encrypt(String plainText, String keyBase64) {
    final encrypter = _encrypterFromKey(keyBase64);

    // AES-GCM recommended 12-byte IV
    final iv = IV.fromSecureRandom(12);

    final encrypted = encrypter.encrypt(plainText, iv: iv);

    // Combine IV + encrypted bytes → Base64 string
    final combinedBytes = iv.bytes + encrypted.bytes;

    return base64.encode(combinedBytes);
  }

  /// Decrypt Base64(iv + ciphertext)
  static String decrypt(String combinedBase64, String keyBase64) {
    final encrypter = _encrypterFromKey(keyBase64);

    final combined = base64.decode(combinedBase64);

    // First 12 bytes → IV
    final iv = IV(Uint8List.fromList(combined.sublist(0, 12)));

    // Rest → Ciphertext
    final cipherBytes = combined.sublist(12);
    final encrypted = Encrypted(Uint8List.fromList(cipherBytes));

    return encrypter.decrypt(encrypted, iv: iv);
  }
}
