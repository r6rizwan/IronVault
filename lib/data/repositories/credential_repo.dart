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

  /// Add a new encrypted credential
  Future<void> addCredential({
    required String title,
    required String username,
    required String password,
    String? notes,
    String? category,
  }) async {
    final key = await secureStorage.readMasterKey();
    if (key == null) throw Exception("Master key missing");

    final encTitle = EncryptionUtil.encrypt(title, key);
    final encUsername = EncryptionUtil.encrypt(username, key);
    final encPassword = EncryptionUtil.encrypt(password, key);
    final encNotes = notes != null ? EncryptionUtil.encrypt(notes, key) : null;
    final encCategory = category != null
        ? EncryptionUtil.encrypt(category, key)
        : null;

    final now = DateTime.now();

    await db
        .into(db.credentials)
        .insert(
          CredentialsCompanion.insert(
            id: _uuid.v4(),
            title: encTitle,
            username: encUsername,
            password: encPassword,
            notes: Value(encNotes),
            category: Value(encCategory),
            isFavorite: const Value(false),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  /// Fetch ALL credentials (decrypted)
  Future<List<Map<String, dynamic>>> getAllDecrypted() async {
    final key = await secureStorage.readMasterKey();
    if (key == null) throw Exception("Master key missing");

    final rows = await db.select(db.credentials).get();

    return rows.map((row) {
      return {
        'id': row.id,
        'title': EncryptionUtil.decrypt(row.title, key),
        'username': EncryptionUtil.decrypt(row.username, key),
        'password': EncryptionUtil.decrypt(row.password, key),
        'notes': row.notes == null
            ? null
            : EncryptionUtil.decrypt(row.notes!, key),
        'category': row.category == null
            ? null
            : EncryptionUtil.decrypt(row.category!, key),
        'isFavorite': row.isFavorite,
        'createdAt': row.createdAt,
        'updatedAt': row.updatedAt,
      };
    }).toList();
  }

  /// Fetch ONLY favorite credentials
  Future<List<Map<String, dynamic>>> getFavoriteDecrypted() async {
    final key = await secureStorage.readMasterKey();
    if (key == null) throw Exception("Master key missing");

    final rows = await (db.select(
      db.credentials,
    )..where((tbl) => tbl.isFavorite.equals(true))).get();

    return rows.map((row) {
      return {
        'id': row.id,
        'title': EncryptionUtil.decrypt(row.title, key),
        'username': EncryptionUtil.decrypt(row.username, key),
        'password': EncryptionUtil.decrypt(row.password, key),
        'notes': row.notes == null
            ? null
            : EncryptionUtil.decrypt(row.notes!, key),
        'category': row.category == null
            ? null
            : EncryptionUtil.decrypt(row.category!, key),
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

  /// Update an existing credential
  Future<void> updateCredential({
    required String id,
    required String title,
    required String username,
    required String password,
    String? notes,
    String? category,
  }) async {
    final key = await secureStorage.readMasterKey();
    if (key == null) throw Exception("Master key missing");

    final now = DateTime.now();

    await (db.update(db.credentials)..where((tbl) => tbl.id.equals(id))).write(
      CredentialsCompanion(
        title: Value(EncryptionUtil.encrypt(title, key)),
        username: Value(EncryptionUtil.encrypt(username, key)),
        password: Value(EncryptionUtil.encrypt(password, key)),
        notes: Value(
          notes == null || notes.trim().isEmpty
              ? null
              : EncryptionUtil.encrypt(notes, key),
        ),
        category: Value(
          category == null || category.trim().isEmpty
              ? null
              : EncryptionUtil.encrypt(category, key),
        ),
        updatedAt: Value(now),
      ),
    );
  }

  /// Delete a credential
  Future<void> deleteCredential(String id) async {
    await (db.delete(db.credentials)..where((tbl) => tbl.id.equals(id))).go();
  }
}
