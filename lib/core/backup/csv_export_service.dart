import 'dart:io';

import 'package:csv/csv.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:ironvault/data/repositories/credential_repo.dart';

class CsvExportService {
  CsvExportService({required this.repo});

  final CredentialRepository repo;

  Future<File> exportPasswordsCsv() async {
    final items = await repo.getAllDecrypted();
    final rows = <List<dynamic>>[
      ['title', 'username', 'password', 'url', 'notes', 'category'],
    ];

    for (final item in items) {
      if ((item['type'] ?? '') != 'password') continue;
      final fields = (item['fields'] as Map?)?.cast<String, dynamic>() ?? {};
      rows.add([
        item['title'] ?? '',
        fields['username'] ?? '',
        fields['password'] ?? '',
        fields['url'] ?? '',
        fields['notes'] ?? '',
        item['category'] ?? '',
      ]);
    }

    final csv = const ListToCsvConverter().convert(rows);
    final dir = await _getExportDirectory();
    final fileName =
        'ironvault_passwords_${DateTime.now().millisecondsSinceEpoch}.csv';
    final file = File(p.join(dir.path, fileName));
    await file.writeAsString(csv, flush: true);
    return file;
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
}
