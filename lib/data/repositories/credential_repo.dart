import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../db/app_db.dart';
import '../../core/utils/encryption_util.dart';
import '../../core/secure_storage.dart';

class CredentialRepository {
  final AppDb db;
  final SecureStorage secureStorage;

  final Uuid _uuid = const Uuid();

  CredentialRepository({required this.db, required this.secureStorage});

  Future<String> _requireMasterKey() async {
    final key = await secureStorage.readMasterKey();
    if (key != null) return key;

    // If key is missing (fresh install or storage reset), generate a new one
    final newKey = EncryptionUtil.generateKeyBase64();
    await secureStorage.writeMasterKey(newKey);
    return newKey;
  }

  String _safeDecrypt(String? value, String key) {
    if (value == null || value.isEmpty) return '';
    try {
      return EncryptionUtil.decrypt(value, key);
    } catch (_) {
      return '';
    }
  }

  /// Add a new encrypted item (password, bank, card, note, document)
  Future<void> addItem({
    required String type,
    required String title,
    required Map<String, String> fields,
    String? category,
  }) async {
    final key = await _requireMasterKey();

    final encTitle = EncryptionUtil.encrypt(title, key);
    final encCategory = category != null
        ? EncryptionUtil.encrypt(category, key)
        : null;

    final jsonFields = jsonEncode(fields);
    final encData = EncryptionUtil.encrypt(jsonFields, key);

    final username = fields['username'] ?? '';
    final password = fields['password'] ?? '';
    final notes = fields['notes'];

    final encUsername = EncryptionUtil.encrypt(username, key);
    final encPassword = EncryptionUtil.encrypt(password, key);
    final encNotes = notes != null && notes.trim().isNotEmpty
        ? EncryptionUtil.encrypt(notes, key)
        : null;

    final now = DateTime.now();

    await db.into(db.credentials).insert(
      CredentialsCompanion.insert(
        id: _uuid.v4(),
        title: encTitle,
        username: encUsername,
        password: encPassword,
        notes: Value(encNotes),
        category: Value(encCategory),
        itemType: Value(type),
        data: Value(encData),
        isFavorite: const Value(false),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  /// Backward-compatible password credential add
  Future<void> addCredential({
    required String title,
    required String username,
    required String password,
    String? notes,
    String? category,
  }) async {
    await addItem(
      type: 'password',
      title: title,
      fields: {
        'username': username,
        'password': password,
        'notes': notes ?? '',
      },
      category: category,
    );
  }

  /// Fetch ALL items (decrypted)
  Future<List<Map<String, dynamic>>> getAllDecrypted() async {
    final key = await _requireMasterKey();

    final rows = await db.select(db.credentials).get();

    return rows.map((row) {
      final type = row.itemType;
      final fields = _decodeFields(row, key);
      return {
        'id': row.id,
        'title': _safeDecrypt(row.title, key),
        'type': type,
        'fields': fields,
        'username': fields['username'] ?? '',
        'password': fields['password'] ?? '',
        'notes': fields['notes'],
        'category': row.category == null
            ? null
            : _safeDecrypt(row.category, key),
        'isFavorite': row.isFavorite,
        'createdAt': row.createdAt,
        'updatedAt': row.updatedAt,
      };
    }).toList();
  }

  /// Fetch ONLY favorite items
  Future<List<Map<String, dynamic>>> getFavoriteDecrypted() async {
    final key = await _requireMasterKey();

    final rows = await (db.select(
      db.credentials,
    )..where((tbl) => tbl.isFavorite.equals(true))).get();

    return rows.map((row) {
      final type = row.itemType;
      final fields = _decodeFields(row, key);
      return {
        'id': row.id,
        'title': _safeDecrypt(row.title, key),
        'type': type,
        'fields': fields,
        'username': fields['username'] ?? '',
        'password': fields['password'] ?? '',
        'notes': fields['notes'],
        'category': row.category == null
            ? null
            : _safeDecrypt(row.category, key),
        'isFavorite': row.isFavorite,
        'createdAt': row.createdAt,
        'updatedAt': row.updatedAt,
      };
    }).toList();
  }

  /// Toggle favorite / un-favorite
  Future<void> toggleFavorite(String id, bool newState) async {
    await (db.update(db.credentials)..where((tbl) => tbl.id.equals(id))).write(
      CredentialsCompanion(
        isFavorite: Value(newState),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Update an existing item
  Future<void> updateItem({
    required String id,
    required String type,
    required String title,
    required Map<String, String> fields,
    String? category,
  }) async {
    final key = await _requireMasterKey();

    final now = DateTime.now();
    final jsonFields = jsonEncode(fields);

    await (db.update(db.credentials)..where((tbl) => tbl.id.equals(id))).write(
      CredentialsCompanion(
        title: Value(EncryptionUtil.encrypt(title, key)),
        username: Value(
          EncryptionUtil.encrypt(fields['username'] ?? '', key),
        ),
        password: Value(
          EncryptionUtil.encrypt(fields['password'] ?? '', key),
        ),
        notes: Value(() {
          final notes = fields['notes'];
          if (notes == null || notes.trim().isEmpty) return null;
          return EncryptionUtil.encrypt(notes, key);
        }()),
        category: Value(
          category == null || category.trim().isEmpty
              ? null
              : EncryptionUtil.encrypt(category, key),
        ),
        itemType: Value(type),
        data: Value(EncryptionUtil.encrypt(jsonFields, key)),
        updatedAt: Value(now),
      ),
    );
  }

  /// Backward-compatible password update
  Future<void> updateCredential({
    required String id,
    required String title,
    required String username,
    required String password,
    String? notes,
    String? category,
  }) async {
    await updateItem(
      id: id,
      type: 'password',
      title: title,
      fields: {
        'username': username,
        'password': password,
        'notes': notes ?? '',
      },
      category: category,
    );
  }

  /// Delete a credential
  Future<void> deleteCredential(String id) async {
    await (db.delete(db.credentials)..where((tbl) => tbl.id.equals(id))).go();
  }

  /// Clear category references for items that match a category name.
  /// Returns number of updated items.
  Future<int> clearCategoryReferences(String categoryName) async {
    final items = await getAllDecrypted();
    var updated = 0;
    for (final item in items) {
      final category = (item['category'] ?? '').toString();
      if (category.toLowerCase() != categoryName.toLowerCase()) continue;
      await updateItem(
        id: item['id'] as String,
        type: item['type'] as String,
        title: item['title'] as String,
        fields: (item['fields'] as Map).cast<String, String>(),
        category: null,
      );
      updated++;
    }
    return updated;
  }

  Map<String, String> _decodeFields(Credential row, String key) {
    if (row.data != null) {
      try {
        final decoded = EncryptionUtil.decrypt(row.data!, key);
        final map = jsonDecode(decoded) as Map<String, dynamic>;
        return map.map((k, v) => MapEntry(k, v?.toString() ?? ''));
      } catch (_) {}
    }

    return {
      'username': _safeDecrypt(row.username, key),
      'password': _safeDecrypt(row.password, key),
      if (row.notes != null) 'notes': _safeDecrypt(row.notes, key),
    };
  }
}
