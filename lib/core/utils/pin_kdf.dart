import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

class PinKdf {
  static const String _scheme = 'pbkdf2_sha256';
  static const int _iterations = 150000;
  static const int _saltLength = 16;
  static const int _dkLength = 32;

  static String hashPin(String pin) {
    final salt = _randomBytes(_saltLength);
    final hash = _pbkdf2(pin, salt, _iterations, _dkLength);
    return '$_scheme\$$_iterations\$${base64.encode(salt)}\$${base64.encode(hash)}';
  }

  static bool verifyPin(String pin, String stored) {
    final parts = stored.split(r'$');
    if (parts.length != 4 || parts[0] != _scheme) {
      return false;
    }

    final iterations = int.tryParse(parts[1]);
    if (iterations == null || iterations <= 0) {
      return false;
    }

    final salt = base64.decode(parts[2]);
    final expected = base64.decode(parts[3]);
    final actual = _pbkdf2(pin, salt, iterations, expected.length);
    return _constantTimeEquals(actual, expected);
  }

  static Uint8List _pbkdf2(
    String password,
    Uint8List salt,
    int iterations,
    int dkLen,
  ) {
    final hmac = Hmac(sha256, utf8.encode(password));
    const int hashLen = 32;
    final blocks = (dkLen / hashLen).ceil();

    final output = BytesBuilder(copy: false);
    for (var blockIndex = 1; blockIndex <= blocks; blockIndex++) {
      output.add(_pbkdf2Block(hmac, salt, iterations, blockIndex));
    }

    final bytes = output.takeBytes();
    return Uint8List.sublistView(Uint8List.fromList(bytes), 0, dkLen);
  }

  static Uint8List _pbkdf2Block(
    Hmac hmac,
    Uint8List salt,
    int iterations,
    int blockIndex,
  ) {
    final blockIndexBytes = Uint8List(4);
    blockIndexBytes[0] = (blockIndex >> 24) & 0xff;
    blockIndexBytes[1] = (blockIndex >> 16) & 0xff;
    blockIndexBytes[2] = (blockIndex >> 8) & 0xff;
    blockIndexBytes[3] = blockIndex & 0xff;

    final first = hmac.convert(_concat(salt, blockIndexBytes)).bytes;
    var u = Uint8List.fromList(first);
    final t = Uint8List.fromList(first);

    for (var i = 1; i < iterations; i++) {
      u = Uint8List.fromList(hmac.convert(u).bytes);
      for (var j = 0; j < t.length; j++) {
        t[j] ^= u[j];
      }
    }

    return t;
  }

  static Uint8List _concat(Uint8List a, Uint8List b) {
    final out = Uint8List(a.length + b.length);
    out.setAll(0, a);
    out.setAll(a.length, b);
    return out;
  }

  static Uint8List _randomBytes(int length) {
    final rnd = Random.secure();
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = rnd.nextInt(256);
    }
    return bytes;
  }

  static bool _constantTimeEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
