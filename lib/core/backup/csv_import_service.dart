import 'dart:io';

import 'package:csv/csv.dart';

import 'package:ironvault/data/repositories/credential_repo.dart';

class CsvImportResult {
  final int imported;
  final int skipped;

  const CsvImportResult({required this.imported, required this.skipped});
}

class CsvImportService {
  CsvImportService({required this.repo});

  final CredentialRepository repo;

  Future<CsvImportResult> importPasswords(File file) async {
    final content = await file.readAsString();
    final rows = const CsvToListConverter(
      eol: '\n',
      shouldParseNumbers: false,
    ).convert(content);

    if (rows.isEmpty) {
      return const CsvImportResult(imported: 0, skipped: 0);
    }

    final headerMap = _buildHeaderMap(rows.first);
    final hasHeader = headerMap.isNotEmpty;
    final dataRows = hasHeader ? rows.skip(1) : rows;

    var imported = 0;
    var skipped = 0;

    for (final row in dataRows) {
      if (row.isEmpty) continue;

      final title = _value(row, headerMap, ['title', 'name', 'item', 'entry']) ??
          _positional(row, 0);
      final username =
          _value(row, headerMap, ['username', 'user', 'login', 'email']) ??
          _positional(row, 1);
      final password =
          _value(row, headerMap, ['password', 'pass', 'secret']) ??
          _positional(row, 2);
      final url = _value(row, headerMap, ['url', 'website', 'site']) ??
          _positional(row, 3);
      final notes = _value(row, headerMap, ['notes', 'note', 'comments']) ??
          _positional(row, 4);
      final category =
          _value(row, headerMap, ['category', 'folder', 'group', 'type']) ??
          _positional(row, 5);

      if ((title ?? '').trim().isEmpty || (password ?? '').trim().isEmpty) {
        skipped++;
        continue;
      }

      await repo.addItemWithMeta(
        type: 'password',
        title: title!.trim(),
        fields: {
          'username': (username ?? '').trim(),
          'password': (password ?? '').trim(),
          'url': (url ?? '').trim(),
          'notes': (notes ?? '').trim(),
        },
        category: (category ?? '').trim().isEmpty ? null : category!.trim(),
        isFavorite: false,
      );
      imported++;
    }

    return CsvImportResult(imported: imported, skipped: skipped);
  }

  Map<String, int> _buildHeaderMap(List<dynamic> headerRow) {
    final map = <String, int>{};
    for (var i = 0; i < headerRow.length; i++) {
      final raw = headerRow[i]?.toString().trim().toLowerCase() ?? '';
      if (raw.isEmpty) continue;
      map[raw] = i;
    }

    const known = {
      'title',
      'name',
      'item',
      'entry',
      'username',
      'user',
      'login',
      'email',
      'password',
      'pass',
      'secret',
      'url',
      'website',
      'site',
      'notes',
      'note',
      'comments',
      'category',
      'folder',
      'group',
      'type',
    };

    final hasKnown = map.keys.any(known.contains);
    return hasKnown ? map : {};
  }

  String? _value(
    List<dynamic> row,
    Map<String, int> headerMap,
    List<String> keys,
  ) {
    for (final key in keys) {
      final idx = headerMap[key];
      if (idx == null || idx >= row.length) continue;
      return row[idx]?.toString();
    }
    return null;
  }

  String? _positional(List<dynamic> row, int index) {
    if (index >= row.length) return null;
    return row[index]?.toString();
  }
}
