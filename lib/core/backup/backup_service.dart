import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:ironvault/core/utils/encryption_util.dart';
import 'package:ironvault/data/repositories/credential_repo.dart';

class BackupService {
  final CredentialRepository repo;

  BackupService({required this.repo});

  Future<File> exportEncryptedBackup({required String password}) async {
    final items = await repo.getAllDecrypted();
    final archive = Archive();

    final exportedItems = <Map<String, dynamic>>[];

    for (final item in items) {
      final fields = (item['fields'] as Map?)?.cast<String, dynamic>() ?? {};

      // Normalize scan paths and add files to zip.
      if ((item['type'] ?? '') == 'document' && fields['scans'] != null) {
        final raw = fields['scans'].toString();
        List<dynamic> scanPaths = [];
        try {
          final decoded = jsonDecode(raw);
          if (decoded is List) scanPaths = decoded;
        } catch (_) {}

        final storedNames = <String>[];
        for (var i = 0; i < scanPaths.length; i++) {
          final path = scanPaths[i].toString();
          final file = File(path);
          if (!file.existsSync()) continue;
          final bytes = file.readAsBytesSync();
          final ext = p.extension(path).isEmpty ? '.jpg' : p.extension(path);
          final name = 'scans/${item['id']}_$i$ext';
          archive.addFile(ArchiveFile(name, bytes.length, bytes));
          storedNames.add(name);
        }
        fields['scans'] = storedNames;
      }

      exportedItems.add({
        'id': item['id'],
        'title': item['title'],
        'type': item['type'],
        'fields': fields,
        'category': item['category'],
        'isFavorite': item['isFavorite'] == true,
        'createdAt': item['createdAt']?.toString(),
        'updatedAt': item['updatedAt']?.toString(),
      });
    }

    final meta = {
      'format': 'ironvault-backup-1',
      'exportedAt': DateTime.now().toIso8601String(),
    };

    final itemsJson = jsonEncode({'meta': meta, 'items': exportedItems});
    archive.addFile(
      ArchiveFile('items.json', itemsJson.length, utf8.encode(itemsJson)),
    );

    final zipData = ZipEncoder().encode(archive);

    final salt = _randomBytes(16);
    final keyBytes = _pbkdf2(password, salt, 150000, 32);
    final keyBase64 = base64.encode(keyBytes);

    final zipBase64 = base64.encode(zipData);
    final cipherText = EncryptionUtil.encrypt(zipBase64, keyBase64);

    final payload = jsonEncode({
      'format': 'ironvault-backup-1',
      'salt': base64.encode(salt),
      'iterations': 150000,
      'ciphertext': cipherText,
    });

    final dir = await _getExportDirectory();
    final fileName =
        'ironvault_backup_${DateTime.now().millisecondsSinceEpoch}.ivault';
    final file = File(p.join(dir.path, fileName));
    await file.writeAsString(payload, flush: true);
    return file;
  }

  Future<int> importEncryptedBackup({
    required File file,
    required String password,
  }) async {
    final payload =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final salt = base64.decode(payload['salt'] as String);
    final iterations = payload['iterations'] as int;
    final cipherText = payload['ciphertext'] as String;

    final keyBytes = _pbkdf2(password, salt, iterations, 32);
    final keyBase64 = base64.encode(keyBytes);
    final zipBase64 = EncryptionUtil.decrypt(cipherText, keyBase64);
    final zipBytes = base64.decode(zipBase64);

    final archive = ZipDecoder().decodeBytes(zipBytes);
    final dir = await getApplicationDocumentsDirectory();
    final importRoot = Directory(p.join(dir.path, 'imported_scans'));
    if (!importRoot.existsSync()) {
      importRoot.createSync(recursive: true);
    }

    Map<String, dynamic>? itemsJson;
    final extractedPaths = <String, String>{};

    for (final fileEntry in archive) {
      if (!fileEntry.isFile) continue;
      final name = fileEntry.name;
      if (name == 'items.json') {
        final content = utf8.decode(fileEntry.content as List<int>);
        itemsJson = jsonDecode(content) as Map<String, dynamic>;
        continue;
      }
      final outPath = p.join(importRoot.path, name);
      final outFile = File(outPath);
      outFile.parent.createSync(recursive: true);
      outFile.writeAsBytesSync(fileEntry.content as List<int>);
      extractedPaths[name] = outFile.path;
    }

    if (itemsJson == null) {
      throw Exception('Invalid backup (items.json missing)');
    }

    final items = (itemsJson['items'] as List<dynamic>? ?? []);
    var imported = 0;

    for (final raw in items) {
      final map = raw as Map<String, dynamic>;
      final type = (map['type'] ?? 'password').toString();
      final title = (map['title'] ?? '').toString();
      final category = (map['category'] ?? '').toString();
      final fieldsRaw = (map['fields'] as Map?)?.cast<String, dynamic>() ?? {};
      final fields = <String, String>{};

      for (final entry in fieldsRaw.entries) {
        fields[entry.key] = entry.value?.toString() ?? '';
      }

      if (type == 'document' && fieldsRaw['scans'] != null) {
        final scans = fieldsRaw['scans'];
        List<String> names = [];
        if (scans is List) {
          names = scans.map((e) => e.toString()).toList();
        }
        final paths = names
            .map((n) => extractedPaths[n])
            .whereType<String>()
            .toList();
        fields['scans'] = jsonEncode(paths);
      }

      await repo.addItemWithMeta(
        type: type,
        title: title,
        fields: fields,
        category: category.isEmpty ? null : category,
        isFavorite: map['isFavorite'] == true,
      );
      imported++;
    }

    return imported;
  }

  Uint8List _pbkdf2(
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

  Future<Directory> _getExportDirectory() async {
    if (Platform.isAndroid) {
      final candidates = <Directory>[
        Directory('/storage/emulated/0/Download'),
        Directory('/sdcard/Download'),
      ];
      for (final dir in candidates) {
        if (dir.existsSync()) {
          return dir;
        }
      }
    }
    return getApplicationDocumentsDirectory();
  }

  Uint8List _pbkdf2Block(
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

  Uint8List _concat(Uint8List a, Uint8List b) {
    final out = Uint8List(a.length + b.length);
    out.setAll(0, a);
    out.setAll(a.length, b);
    return out;
  }

  Uint8List _randomBytes(int length) {
    final rnd = Random.secure();
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = rnd.nextInt(256);
    }
    return bytes;
  }
}
