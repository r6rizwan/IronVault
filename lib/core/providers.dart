// lib/core/providers.dart
// Centralized providers to avoid circular imports between UI screens and main.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:ironvault/core/secure_storage.dart';
import 'package:ironvault/data/db/app_db.dart';
import 'package:ironvault/data/repositories/credential_repo.dart';

final secureStorageProvider = Provider((ref) => SecureStorage());

final dbProvider = Provider((ref) => AppDb());

final credentialRepoProvider = Provider(
  (ref) => CredentialRepository(
    db: ref.read(dbProvider),
    secureStorage: ref.read(secureStorageProvider),
  ),
);

// Increment this to trigger list refreshes after add/edit.
final vaultRefreshProvider = StateProvider<int>((ref) => 0);
