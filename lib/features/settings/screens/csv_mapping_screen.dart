// SPDX-FileCopyrightText: 2025-2026 Rizwan Mulla
// SPDX-License-Identifier: GPL-3.0-only
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:csv/csv.dart';
import 'package:ironvault/core/providers.dart';
import 'package:ironvault/core/theme/app_tokens.dart';
import 'package:ironvault/core/widgets/app_toast.dart';
import 'package:ironvault/core/widgets/blocking_loading_overlay.dart';

class CsvMappingScreen extends ConsumerStatefulWidget {
  final File file;

  const CsvMappingScreen({super.key, required this.file});

  @override
  ConsumerState<CsvMappingScreen> createState() => _CsvMappingScreenState();
}

class _CsvMappingScreenState extends ConsumerState<CsvMappingScreen> {
  List<List<dynamic>> _rows = [];
  List<String> _headers = [];
  bool _loading = true;
  String? _error;

  // Mapping state: key is target field, value is index of CSV header (-1 means unmapped)
  final Map<String, int> _mappings = {
    'title': -1,
    'username': -1,
    'password': -1,
    'url': -1,
    'notes': -1,
    'category': -1,
  };

  final List<String> _targetFields = [
    'title',
    'username',
    'password',
    'url',
    'notes',
    'category',
  ];

  String _importMode = 'match';
  String _matchStrategy = 'skip';

  @override
  void initState() {
    super.initState();
    _parseCsv();
  }

  Future<void> _parseCsv() async {
    try {
      final content = await widget.file.readAsString();
      final parsed = const CsvToListConverter(
        eol: '\n',
        shouldParseNumbers: false,
      ).convert(content);

      if (parsed.isEmpty) {
        setState(() {
          _error = 'CSV file is empty';
          _loading = false;
        });
        return;
      }

      final rawHeaders = parsed.first
          .map((e) => e?.toString().trim() ?? '')
          .toList();
      setState(() {
        _rows = parsed;
        _headers = rawHeaders;
        _loading = false;
      });

      _autoMapHeaders(rawHeaders);
    } catch (e) {
      setState(() {
        _error = 'Failed to parse CSV: $e';
        _loading = false;
      });
    }
  }

  void _autoMapHeaders(List<String> headers) {
    final heuristics = {
      'title': ['title', 'name', 'item', 'entry'],
      'username': ['username', 'user', 'login', 'email'],
      'password': ['password', 'pass', 'secret'],
      'url': ['url', 'website', 'site', 'link'],
      'notes': ['notes', 'note', 'comments', 'comment'],
      'category': ['category', 'folder', 'group', 'type'],
    };

    for (final field in _targetFields) {
      final matches = heuristics[field] ?? [];
      for (var i = 0; i < headers.length; i++) {
        final cleanHeader = headers[i].toLowerCase();
        if (matches.any(
          (m) => cleanHeader.contains(m) || m.contains(cleanHeader),
        )) {
          _mappings[field] = i;
          break;
        }
      }
    }

    // Positional fallback if no header match found
    if (_mappings['title'] == -1 && headers.isNotEmpty) _mappings['title'] = 0;
    if (_mappings['username'] == -1 && headers.length > 1) {
      _mappings['username'] = 1;
    }
    if (_mappings['password'] == -1 && headers.length > 2) {
      _mappings['password'] = 2;
    }

    setState(() {});
  }

  bool get _isValid {
    // Title and Password are basic requirements for a valid credentials entry
    return _mappings['title'] != -1 && _mappings['password'] != -1;
  }

  String _mappedValue(List<dynamic> row, String field) {
    final index = _mappings[field] ?? -1;
    if (index < 0 || index >= row.length) return '';
    return row[index]?.toString().trim() ?? '';
  }

  List<List<dynamic>> get _dataRows => _rows.skip(1).toList();

  int get _validRowCount => _dataRows.where((row) {
    return _mappedValue(row, 'title').isNotEmpty &&
        _mappedValue(row, 'password').isNotEmpty;
  }).length;

  String _duplicateKey(String title, String username) =>
      '${title.trim().toLowerCase()}\u0000${username.trim().toLowerCase()}';

  List<Map<String, dynamic>> _findDuplicates(
    List<Map<String, dynamic>> existingItems,
  ) {
    final importKeys = _dataRows
        .where(
          (row) =>
              _mappedValue(row, 'title').isNotEmpty &&
              _mappedValue(row, 'password').isNotEmpty,
        )
        .map(
          (row) => _duplicateKey(
            _mappedValue(row, 'title'),
            _mappedValue(row, 'username'),
          ),
        )
        .toSet();

    return existingItems.where((item) {
      if (item['type'] != 'password') return false;
      return importKeys.contains(
        _duplicateKey(
          item['title']?.toString() ?? '',
          item['username']?.toString() ?? '',
        ),
      );
    }).toList();
  }

  Future<bool> _confirmMerge(List<Map<String, dynamic>> duplicates) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update matching items?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${duplicates.length} existing item(s) match by title and username.',
              ),
              const SizedBox(height: 8),
              const Text(
                'Non-empty imported fields will replace their saved values. '
                'Blank or unmapped fields will be kept.',
              ),
              const SizedBox(height: 12),
              ...duplicates.take(5).map((item) {
                final username = item['username']?.toString() ?? '';
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(item['title']?.toString() ?? 'Untitled'),
                  subtitle: username.isEmpty ? null : Text(username),
                );
              }),
              if (duplicates.length > 5)
                Text('And ${duplicates.length - 5} more...'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Update items'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _runImport() async {
    if (!_isValid) {
      showAppToast(context, 'Title and Password mappings are required');
      return;
    }

    final repo = ref.read(credentialRepoProvider);
    List<Map<String, dynamic>> existingItems = [];
    if (_importMode == 'match') {
      try {
        existingItems = await repo.getAllDecrypted();
      } catch (_) {
        if (mounted) showAppToast(context, 'Could not check for duplicates');
        return;
      }
    }
    if (_importMode == 'match' && _matchStrategy == 'merge') {
      final duplicates = _findDuplicates(existingItems);
      if (duplicates.isNotEmpty && !await _confirmMerge(duplicates)) return;
    }
    if (!mounted) return;
    setState(() => _loading = true);

    int imported = 0;
    int updated = 0;
    int skipped = 0;
    int failed = 0;

    final dataRows = _rows.skip(1); // skip headers
    final createdKeys = <String>{};

    for (final row in dataRows) {
      final title = _mappedValue(row, 'title');
      final password = _mappedValue(row, 'password');

      if (title.isEmpty || password.isEmpty) {
        skipped++;
        continue;
      }

      final username = _mappedValue(row, 'username');
      final url = _mappedValue(row, 'url');
      final notes = _mappedValue(row, 'notes');
      final category = _mappedValue(row, 'category');
      final key = _duplicateKey(title, username);
      final duplicateIndexes = [
        for (var index = 0; index < existingItems.length; index++)
          if (existingItems[index]['type'] == 'password' &&
              _duplicateKey(
                    existingItems[index]['title']?.toString() ?? '',
                    existingItems[index]['username']?.toString() ?? '',
                  ) ==
                  key)
            index,
      ];

      if (_importMode == 'match' &&
          _matchStrategy == 'skip' &&
          duplicateIndexes.isNotEmpty) {
        skipped++;
        continue;
      }

      if (_importMode == 'match' &&
          _matchStrategy == 'merge' &&
          duplicateIndexes.isNotEmpty) {
        for (final duplicateIndex in duplicateIndexes) {
          final existing = existingItems[duplicateIndex];
          final oldFields =
              (existing['fields'] as Map?)?.map(
                (fieldKey, value) =>
                    MapEntry(fieldKey.toString(), value?.toString() ?? ''),
              ) ??
              <String, String>{};
          final mergedFields = <String, String>{
            ...oldFields,
            if (username.isNotEmpty) 'username': username,
            if (password.isNotEmpty) 'password': password,
            if (url.isNotEmpty) 'url': url,
            if (notes.isNotEmpty) 'notes': notes,
          };
          final mergedCategory = category.isNotEmpty
              ? category
              : existing['category']?.toString();

          try {
            await repo.updateItem(
              id: existing['id'].toString(),
              type: 'password',
              title: existing['title']?.toString() ?? title,
              fields: mergedFields,
              category: mergedCategory,
            );
            existingItems[duplicateIndex] = {
              ...existing,
              'fields': mergedFields,
              'username': mergedFields['username'] ?? '',
              'password': mergedFields['password'] ?? '',
              'category': mergedCategory,
            };
            updated++;
          } catch (_) {
            failed++;
          }
        }
        continue;
      }

      if (_importMode == 'match' && createdKeys.contains(key)) {
        skipped++;
        continue;
      }

      try {
        await repo.addItemWithMeta(
          type: 'password',
          title: title,
          fields: {
            'username': username,
            'password': password,
            'url': url,
            'notes': notes,
          },
          category: category.isEmpty ? null : category,
          isFavorite: false,
        );
        createdKeys.add(key);
        imported++;
      } catch (_) {
        failed++;
      }
    }

    ref.read(vaultRefreshProvider.notifier).state++;
    if (!mounted) return;

    setState(() => _loading = false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Import Results'),
        content: Text(
          'Successfully imported: $imported\n'
          'Updated existing: $updated\n'
          'Skipped/Duplicates: $skipped\n'
          'Failed items: $failed',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); // pop dialog
              Navigator.pop(context); // pop mapping screen
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textColor = AppThemeColors.text(context);

    if (_loading && _rows.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Import CSV')),
        body: Center(
          child: Text(_error!, style: const TextStyle(color: Colors.red)),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configure CSV Import'),
        actions: [
          TextButton(
            onPressed: _isValid ? _runImport : null,
            child: Text(
              'Import',
              style: TextStyle(
                color: _isValid
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: BlockingLoadingOverlay(
        isLoading: _loading,
        message: 'Importing credentials...',
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'How should IronVault handle existing items?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            RadioGroup<String>(
              groupValue: _importMode,
              onChanged: (val) {
                if (val != null) setState(() => _importMode = val);
              },
              child: Column(
                children: [
                  RadioListTile<String>(
                    value: 'match',
                    title: const Text('Check for matching items'),
                    subtitle: const Text(
                      'Match by title and username, then choose what to do',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  if (_importMode == 'match')
                    Padding(
                      padding: const EdgeInsets.only(left: 24),
                      child: RadioGroup<String>(
                        groupValue: _matchStrategy,
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _matchStrategy = val);
                          }
                        },
                        child: Column(
                          children: [
                            RadioListTile<String>(
                              dense: true,
                              value: 'skip',
                              title: const Text('Skip matching rows'),
                            ),
                            RadioListTile<String>(
                              dense: true,
                              value: 'merge',
                              title: const Text('Review and update matches'),
                              subtitle: const Text(
                                'Imported non-empty fields replace saved values',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  RadioListTile<String>(
                    value: 'add_new',
                    title: const Text('Import as new items'),
                    subtitle: const Text(
                      'Do not match against items already in this vault',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 32),
            const Text(
              'Map CSV Columns',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select which columns in your CSV file match the Vault target fields. (Title and Password are required)',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ..._targetFields.map((field) {
              final isRequired = field == 'title' || field == 'password';
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${field.toUpperCase()}${isRequired ? " *" : ""}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isRequired
                                ? Theme.of(context).colorScheme.primary
                                : textColor,
                          ),
                        ),
                      ),
                      DropdownButton<int>(
                        value: _mappings[field] == -1 ? null : _mappings[field],
                        hint: const Text('Ignore/Skip'),
                        items: [
                          DropdownMenuItem<int>(
                            value: null,
                            child: const Text('Ignore/Skip'),
                          ),
                          ...List.generate(_headers.length, (index) {
                            return DropdownMenuItem<int>(
                              value: index,
                              child: Text(_headers[index]),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _mappings[field] = val ?? -1;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Import preview',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isValid
                          ? '$_validRowCount rows ready; '
                                '${_dataRows.length - _validRowCount} will be skipped '
                                'because title or password is missing.'
                          : 'Map both Title and Password to preview valid rows.',
                    ),
                    if (_isValid) ...[
                      const Divider(height: 24),
                      ..._dataRows.take(5).map((row) {
                        final title = _mappedValue(row, 'title');
                        final username = _mappedValue(row, 'username');
                        final valid =
                            title.isNotEmpty &&
                            _mappedValue(row, 'password').isNotEmpty;
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            valid
                                ? Icons.check_circle_outline
                                : Icons.warning_amber,
                            color: valid
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.error,
                          ),
                          title: Text(
                            title.isEmpty ? 'Missing title' : title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: username.isEmpty ? null : Text(username),
                          trailing: valid
                              ? null
                              : const Text(
                                  'Will skip',
                                  style: TextStyle(fontSize: 12),
                                ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
