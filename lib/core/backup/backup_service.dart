// SPDX-FileCopyrightText: 2025-2026 Rizwan Mulla
// SPDX-License-Identifier: GPL-3.0-only
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:ironvault/core/utils/encryption_util.dart';
import 'package:ironvault/data/repositories/credential_repository.dart';

class BackupImportResult {
  final int imported;
  final int failed;

  const BackupImportResult({required this.imported, required this.failed});
}

class BackupRestoreException implements Exception {
  final String message;

  const BackupRestoreException(this.message);

  @override
  String toString() => message;
}

class BackupService {
  final CredentialRepository repo;
  static const _formatV1 = 'ironvault-backup-1';
  static const _formatV2 = 'ironvault-backup-2';

  BackupService({required this.repo});

  static Future<void> validateEncryptedBackupFile(File file) async {
    await _readAndValidatePayload(file);
  }

  static Future<Map<String, dynamic>> _readAndValidatePayload(File file) async {
    late final Map<String, dynamic> payload;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      payload = decoded;
    } catch (_) {
      throw const BackupRestoreException(
        'This file is not a valid IronVault encrypted backup.',
      );
    }

    final format = payload['format'];
    if (format != _formatV1 && format != _formatV2) {
      throw const BackupRestoreException(
        'This backup format is not supported by this version of IronVault.',
      );
    }
    final salt = payload['salt'];
    final iterations = payload['iterations'];
    final ciphertext = payload['ciphertext'];
    if (salt is! String ||
        iterations is! int ||
        iterations < 100000 ||
        iterations > 1000000 ||
        ciphertext is! String) {
      throw const BackupRestoreException(
        'The backup file is incomplete or invalid.',
      );
    }
    try {
      if (base64.decode(salt).length != 16 ||
          base64.decode(ciphertext).length <= 28) {
        throw const FormatException();
      }
    } catch (_) {
      throw const BackupRestoreException(
        'The backup file is incomplete or invalid.',
      );
    }
    return payload;
  }

  Future<File> exportEncryptedBackup({required String password}) async {
    final items = await repo.getAllDecrypted();
    final archive = Archive();

    final exportedItems = <Map<String, dynamic>>[];

    for (final item in items) {
      final rawFields = (item['fields'] as Map?)?.cast<String, dynamic>() ?? {};
      final fields = Map<String, dynamic>.from(rawFields);

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
      'format': _formatV2,
      'exportedAt': DateTime.now().toIso8601String(),
    };

    final itemsJson = jsonEncode({'meta': meta, 'items': exportedItems});
    final itemsBytes = utf8.encode(itemsJson);
    archive.addFile(
      ArchiveFile('items.json', itemsBytes.length, itemsBytes),
    );

    final zipData = ZipEncoder().encode(archive);

    final salt = _randomBytes(16);
    final keyBytes = _pbkdf2(password, salt, 150000, 32);
    final keyBase64 = base64.encode(keyBytes);

    final archiveChecksum = sha256.convert(zipData).toString();
    final encryptedContent = jsonEncode({
      'archive': base64.encode(zipData),
      'checksumAlgorithm': 'sha256',
      'checksum': archiveChecksum,
    });
    final cipherText = EncryptionUtil.encrypt(encryptedContent, keyBase64);

    final payload = jsonEncode({
      'format': _formatV2,
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

  Future<BackupImportResult> importEncryptedBackup({
    required File file,
    required String password,
  }) async {
    final payload = await _readAndValidatePayload(file);
    final format = payload['format'];
    final saltValue = payload['salt'] as String;
    final iterationsValue = payload['iterations'] as int;
    final cipherText = payload['ciphertext'];

    late final Uint8List zipBytes;
    try {
      final salt = base64.decode(saltValue);
      final keyBytes = _pbkdf2(password, salt, iterationsValue, 32);
      final keyBase64 = base64.encode(keyBytes);
      final decrypted = EncryptionUtil.decrypt(cipherText as String, keyBase64);
      if (format == _formatV1) {
        zipBytes = Uint8List.fromList(base64.decode(decrypted));
      } else {
        final content = jsonDecode(decrypted);
        if (content is! Map<String, dynamic> ||
            content['checksumAlgorithm'] != 'sha256' ||
            content['archive'] is! String ||
            content['checksum'] is! String) {
          throw const FormatException();
        }
        zipBytes = Uint8List.fromList(base64.decode(content['archive'] as String));
        final actualChecksum = sha256.convert(zipBytes).toString();
        if (actualChecksum != content['checksum']) {
          throw const BackupRestoreException(
            'Backup integrity verification failed. The file may be damaged.',
          );
        }
      }
    } on BackupRestoreException {
      rethrow;
    } catch (_) {
      throw const BackupRestoreException(
        'Could not unlock the backup. Check the password or choose an undamaged backup file.',
      );
    }

    late final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(zipBytes);
    } catch (_) {
      throw const BackupRestoreException('The backup contents are damaged or invalid.');
    }
    final dir = await getApplicationDocumentsDirectory();
    final importRoot = Directory(p.join(dir.path, 'imported_scans'));

    Map<String, dynamic>? itemsJson;
    final scanContents = <String, List<int>>{};

    for (final fileEntry in archive) {
      if (!fileEntry.isFile) continue;
      final name = fileEntry.name;
      if (name == 'items.json') {
        try {
          final content = utf8.decode(fileEntry.content as List<int>);
          final decoded = jsonDecode(content);
          if (decoded is! Map<String, dynamic>) throw const FormatException();
          itemsJson = decoded;
        } catch (_) {
          throw const BackupRestoreException('The backup item data is invalid.');
        }
        continue;
      }
      final normalizedName = p.normalize(name);
      if (p.isAbsolute(name) ||
          normalizedName.startsWith('..${p.separator}') ||
          normalizedName == '..' ||
          !normalizedName.startsWith('scans${p.separator}')) {
        throw const BackupRestoreException('The backup contains an invalid attachment path.');
      }
      scanContents[normalizedName] = fileEntry.content as List<int>;
    }

    if (itemsJson == null) {
      throw const BackupRestoreException('The backup is missing its item data.');
    }

    final meta = itemsJson['meta'];
    final itemsValue = itemsJson['items'];
    if (meta is! Map<String, dynamic> ||
        meta['format'] != format ||
        itemsValue is! List) {
      throw const BackupRestoreException(
        'This backup is incomplete or uses an unsupported data format.',
      );
    }
    final items = itemsValue;
    final preparedItems = <Map<String, dynamic>>[];
    for (final raw in items) {
      if (raw is! Map<String, dynamic> ||
          raw['title'] is! String ||
          raw['type'] is! String ||
          raw['fields'] is! Map) {
        throw const BackupRestoreException('The backup contains an invalid item record.');
      }
      final fieldsRaw = (raw['fields'] as Map).cast<String, dynamic>();
      if (raw['type'] == 'document' && fieldsRaw['scans'] != null) {
        final scans = fieldsRaw['scans'];
        if (scans is! List ||
            scans.any((scan) => scan is! String || !scanContents.containsKey(scan))) {
          throw const BackupRestoreException(
            'A document attachment is missing from the backup.',
          );
        }
      }
      preparedItems.add(raw);
    }

    if (scanContents.isNotEmpty) {
      importRoot.createSync(recursive: true);
    }
    final extractedPaths = <String, String>{};
    for (final entry in scanContents.entries) {
      final outPath = p.join(importRoot.path, entry.key);
      final outFile = File(outPath);
      outFile.parent.createSync(recursive: true);
      outFile.writeAsBytesSync(entry.value, flush: true);
      extractedPaths[entry.key] = outFile.path;
    }

    var imported = 0;
    var failed = 0;

    for (final map in preparedItems) {
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
        final names = (scans as List).map((e) => e.toString()).toList();
        final paths = names
            .map((n) => extractedPaths[n])
            .whereType<String>()
            .toList();
        fields['scans'] = jsonEncode(paths);
      }

      try {
        await repo.addItemWithMeta(
          type: type,
          title: title,
          fields: fields,
          category: category.isEmpty ? null : category,
          isFavorite: map['isFavorite'] == true,
        );
        imported++;
      } catch (_) {
        failed++;
      }
    }

    return BackupImportResult(imported: imported, failed: failed);
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
