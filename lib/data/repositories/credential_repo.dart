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
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  /// Fetch and decrypt all credentials
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
        'createdAt': row.createdAt,
        'updatedAt': row.updatedAt,
      };
    }).toList();
  }
}
