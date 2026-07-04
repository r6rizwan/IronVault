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

  // Conflict Resolution Strategy
  String _duplicateStrategy = 'skip'; // 'skip' or 'add_new'

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

  Future<void> _runImport() async {
    if (!_isValid) {
      showAppToast(context, 'Title and Password mappings are required');
      return;
    }

    setState(() => _loading = true);

    final repo = ref.read(credentialRepoProvider);
    final titleIndex = _mappings['title']!;
    final passwordIndex = _mappings['password']!;
    final usernameIndex = _mappings['username']!;
    final urlIndex = _mappings['url']!;
    final notesIndex = _mappings['notes']!;
    final categoryIndex = _mappings['category']!;

    int imported = 0;
    int skipped = 0;
    int failed = 0;

    final dataRows = _rows.skip(1); // skip headers

    // Fetch existing list for duplicate checks if needed
    List<Map<String, dynamic>> existingItems = [];
    if (_duplicateStrategy == 'skip') {
      existingItems = await repo.getAllDecrypted();
    }

    for (final row in dataRows) {
      if (row.isEmpty ||
          row.length <= titleIndex ||
          row.length <= passwordIndex) {
        skipped++;
        continue;
      }

      final title = row[titleIndex]?.toString().trim() ?? '';
      final password = row[passwordIndex]?.toString().trim() ?? '';

      if (title.isEmpty || password.isEmpty) {
        skipped++;
        continue;
      }

      final username = usernameIndex != -1 && row.length > usernameIndex
          ? row[usernameIndex]?.toString().trim() ?? ''
          : '';
      final url = urlIndex != -1 && row.length > urlIndex
          ? row[urlIndex]?.toString().trim() ?? ''
          : '';
      final notes = notesIndex != -1 && row.length > notesIndex
          ? row[notesIndex]?.toString().trim() ?? ''
          : '';
      final category = categoryIndex != -1 && row.length > categoryIndex
          ? row[categoryIndex]?.toString().trim() ?? ''
          : '';

      // Check duplicate strategy
      if (_duplicateStrategy == 'skip') {
        final isDuplicate = existingItems.any(
          (item) =>
              item['title'].toString().toLowerCase() == title.toLowerCase() &&
              item['username'].toString().toLowerCase() ==
                  username.toLowerCase(),
        );
        if (isDuplicate) {
          skipped++;
          continue;
        }
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
            const SizedBox(height: 16),
            const Text(
              'Duplicate Strategy',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            RadioGroup<String>(
              groupValue: _duplicateStrategy,
              onChanged: (val) {
                if (val != null) setState(() => _duplicateStrategy = val);
              },
              child: Column(
                children: [
                  RadioListTile<String>(
                    value: 'skip',
                    title: const Text('Skip duplicate entries'),
                    subtitle: const Text(
                      'Does not import if title and username already exist',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  RadioListTile<String>(
                    value: 'add_new',
                    title: const Text('Import all entries'),
                    subtitle: const Text(
                      'Create new records even if they already exist',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
