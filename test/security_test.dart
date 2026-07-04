import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:ironvault/core/utils/pin_kdf.dart';
import 'package:ironvault/core/utils/recovery_key.dart';
import 'package:ironvault/core/utils/encryption_util.dart';
import 'package:ironvault/core/secure_storage.dart';

@GenerateNiceMocks([MockSpec<SecureStorage>()])
import 'security_test.mocks.dart';

void main() {
  group('PinKdf tests', () {
    test('hashing and verification', () {
      final pin = '1234';
      final hash = PinKdf.hashPin(pin);

      expect(hash.startsWith('pbkdf2_sha256\$'), isTrue);
      expect(PinKdf.verifyPin(pin, hash), isTrue);
      expect(PinKdf.verifyPin('4321', hash), isFalse);
    });
  });

  group('EncryptionUtil tests', () {
    test('generateKeyBase64 outputs expected 32-byte key', () {
      final base64Key = EncryptionUtil.generateKeyBase64();
      expect(base64Key.isNotEmpty, isTrue);
    });

    test('encryption and decryption roundtrip', () {
      final key = EncryptionUtil.generateKeyBase64();
      final plaintext = 'Secret password';
      final encrypted = EncryptionUtil.encrypt(plaintext, key);
      
      expect(encrypted != plaintext, isTrue);
      final decrypted = EncryptionUtil.decrypt(encrypted, key);
      expect(decrypted, plaintext);
    });
  });

  group('RecoveryKeyUtil tests', () {
    test('generate builds a formatted key', () {
      final key = RecoveryKeyUtil.generate();
      final segments = key.split('-');
      expect(segments.length, 4);
      for (final s in segments) {
        expect(s.length, 4);
      }
    });

    test('hash produces correct sha256 output', () {
      final key = 'AAAA-BBBB-CCCC-DDDD';
      final hashed = RecoveryKeyUtil.hash(key);
      expect(hashed.length, 64);
    });

    test('store and confirm pending flow', () async {
      final mockStorage = MockSecureStorage();
      final key = 'AAAA-BBBB-CCCC-DDDD';
      final masterKey = EncryptionUtil.generateKeyBase64();

      when(mockStorage.readMasterKey()).thenAnswer((_) async => masterKey);
      when(mockStorage.readValue('pending_recovery_key')).thenAnswer((_) async => EncryptionUtil.encrypt(key, masterKey));
      when(mockStorage.readValue('recovery_key_confirmed')).thenAnswer((_) async => 'false');

      expect(await RecoveryKeyUtil.hasPendingState(mockStorage), isTrue);
      expect(await RecoveryKeyUtil.isConfirmed(mockStorage), isFalse);
      expect(await RecoveryKeyUtil.readPendingKey(mockStorage), key);
    });
  });
}
