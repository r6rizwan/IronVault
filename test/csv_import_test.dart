import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ironvault/core/backup/csv_import_service.dart';
import 'package:ironvault/core/secure_storage.dart';
import 'package:ironvault/data/db/app_db.dart';
import 'package:ironvault/data/repositories/credential_repository.dart';
import 'package:mockito/mockito.dart';

class MockAppDb extends Mock implements AppDb {}

class MockSecureStorage extends Mock implements SecureStorage {}

class RecordingCredentialRepository extends CredentialRepository {
  RecordingCredentialRepository()
    : super(db: MockAppDb(), secureStorage: MockSecureStorage());

  final List<ImportCall> calls = [];

  @override
  Future<void> addItemWithMeta({
    required String type,
    required String title,
    required Map<String, String> fields,
    String? category,
    bool isFavorite = false,
  }) async {
    calls.add(
      ImportCall(
        type: type,
        title: title,
        fields: fields,
        category: category,
        isFavorite: isFavorite,
      ),
    );
  }
}

class ImportCall {
  const ImportCall({
    required this.type,
    required this.title,
    required this.fields,
    required this.category,
    required this.isFavorite,
  });

  final String type;
  final String title;
  final Map<String, String> fields;
  final String? category;
  final bool isFavorite;
}

void main() {
  late RecordingCredentialRepository repo;
  late CsvImportService service;

  setUp(() {
    repo = RecordingCredentialRepository();
    service = CsvImportService(repo: repo);
  });

  group('CsvImportService', () {
    test('imports rows using recognized header names', () async {
      final file = await _writeTempFile(
        'Title,Username,Password,Url,Notes,Category\n'
        'My Account,alice,super-secret,https://example.com,Work notes,Work\n',
      );

      final result = await service.importPasswords(file);

      expect(result.imported, 1);
      expect(result.skipped, 0);
      expect(repo.calls, hasLength(1));
      expect(
        repo.calls.single,
        isA<ImportCall>()
            .having((call) => call.type, 'type', 'password')
            .having((call) => call.title, 'title', 'My Account')
            .having((call) => call.fields, 'fields', {
              'username': 'alice',
              'password': 'super-secret',
              'url': 'https://example.com',
              'notes': 'Work notes',
            })
            .having((call) => call.category, 'category', 'Work')
            .having((call) => call.isFavorite, 'isFavorite', false),
      );
    });

    test(
      'falls back to positional columns when no known headers are present',
      () async {
        final file = await _writeTempFile(
          'Example Account,alice,super-secret,https://example.com,Work notes,Work\n',
        );

        final result = await service.importPasswords(file);

        expect(result.imported, 1);
        expect(result.skipped, 0);
        expect(repo.calls, hasLength(1));
        expect(
          repo.calls.single,
          isA<ImportCall>()
              .having((call) => call.type, 'type', 'password')
              .having((call) => call.title, 'title', 'Example Account')
              .having((call) => call.fields, 'fields', {
                'username': 'alice',
                'password': 'super-secret',
                'url': 'https://example.com',
                'notes': 'Work notes',
              })
              .having((call) => call.category, 'category', 'Work')
              .having((call) => call.isFavorite, 'isFavorite', false),
        );
      },
    );

    test('skips rows missing a title or password', () async {
      final file = await _writeTempFile(
        'Title,Username,Password\n'
        'Missing Password,,\n'
        'Missing Title,alice,secret\n',
      );

      final result = await service.importPasswords(file);

      expect(result.imported, 1);
      expect(result.skipped, 1);
      expect(repo.calls, hasLength(1));
      expect(
        repo.calls.single,
        isA<ImportCall>()
            .having((call) => call.type, 'type', 'password')
            .having((call) => call.title, 'title', 'Missing Title')
            .having((call) => call.fields, 'fields', {
              'username': 'alice',
              'password': 'secret',
              'url': '',
              'notes': '',
            })
            .having((call) => call.category, 'category', null)
            .having((call) => call.isFavorite, 'isFavorite', false),
      );
    });
  });
}

Future<File> _writeTempFile(String content) async {
  final dir = await Directory.systemTemp.createTemp('csv_import_test');
  final file = File('${dir.path}/import.csv');
  await file.writeAsString(content);
  return file;
}
