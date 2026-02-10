// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../domain/entities/vault_category.dart';

class CategoryRepository {
  static const _dbName = 'ironvault.db';
  static const _dbVersion = 1;
  static const _table = 'categories';

  static Database? _db;
  static final CategoryRepository instance = CategoryRepository._internal();
  CategoryRepository._internal();

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final docs = await getApplicationDocumentsDirectory();
    final path = join(docs.path, _dbName);
    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            iconKey TEXT NOT NULL,
            colorValue INTEGER NOT NULL
          );
        ''');

        await db.insert(_table, {
          'name': 'Banking',
          'iconKey': 'bank',
          'colorValue': 0xFF3B82F6,
        });
        await db.insert(_table, {
          'name': 'Social',
          'iconKey': 'web',
          'colorValue': 0xFF8B5CF6,
        });
        await db.insert(_table, {
          'name': 'Email',
          'iconKey': 'email',
          'colorValue': 0xFFF97316,
        });
        await db.insert(_table, {
          'name': 'Work',
          'iconKey': 'other',
          'colorValue': 0xFF10B981,
        });
        await db.insert(_table, {
          'name': 'Personal',
          'iconKey': 'note',
          'colorValue': 0xFF06B6D4,
        });
        await db.insert(_table, {
          'name': 'Shopping',
          'iconKey': 'credit_card',
          'colorValue': 0xFFEF4444,
        });
      },
    );
  }

  Future<List<VaultCategory>> getAll() async {
    await ensureDefaults();
    final database = await db;
    final rows = await database.query(_table, orderBy: 'name COLLATE NOCASE');
    return rows.map((r) => VaultCategory.fromMap(r)).toList();
  }

  Future<void> ensureDefaults() async {
    final database = await db;
    final existing = await database.query(_table, columns: ['name']);
    final names = existing
        .map((r) => (r['name'] as String).toLowerCase())
        .toSet();

    // Remove legacy categories that overlap with item types.
    const blocked = [
      'passwords',
      'bank accounts',
      'bank account',
      'bank cards',
      'bank card',
      'secure notes',
      'secure note',
      'id documents',
      'id document',
      'documents',
      'document',
      'cards',
      'card',
    ];
    final removed = <String>[];
    for (final name in blocked) {
      if (names.contains(name)) {
        await database.delete(
          _table,
          where: 'LOWER(name) = ?',
          whereArgs: [name],
        );
        names.remove(name);
        removed.add(name);
      }
    }

    if (removed.isNotEmpty) {
      await _appendMigrationLog(removed);
    }

    Future<void> insertIfMissing({
      required String name,
      required String iconKey,
      required int colorValue,
    }) async {
      if (names.contains(name.toLowerCase())) return;
      await database.insert(_table, {
        'name': name,
        'iconKey': iconKey,
        'colorValue': colorValue,
      });
      names.add(name.toLowerCase());
    }

    await insertIfMissing(
      name: 'Banking',
      iconKey: 'bank',
      colorValue: 0xFF3B82F6,
    );
    await insertIfMissing(
      name: 'Social',
      iconKey: 'web',
      colorValue: 0xFF8B5CF6,
    );
    await insertIfMissing(
      name: 'Email',
      iconKey: 'email',
      colorValue: 0xFFF97316,
    );
    await insertIfMissing(
      name: 'Work',
      iconKey: 'other',
      colorValue: 0xFF10B981,
    );
    await insertIfMissing(
      name: 'Personal',
      iconKey: 'note',
      colorValue: 0xFF06B6D4,
    );
    await insertIfMissing(
      name: 'Shopping',
      iconKey: 'credit_card',
      colorValue: 0xFFEF4444,
    );
  }

  Future<void> _appendMigrationLog(List<String> removed) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(join(dir.path, 'migration.log'));
    final line =
        '[${DateTime.now().toIso8601String()}] Removed categories: ${removed.join(', ')}\n';
    await file.writeAsString(line, mode: FileMode.append, flush: true);
  }

  Future<VaultCategory> insert(VaultCategory c) async {
    final database = await db;
    final id = await database.insert(_table, c.toMap());
    return c.copyWith(id: id);
  }

  Future<int> update(VaultCategory c) async {
    final database = await db;
    return database.update(
      _table,
      c.toMap(),
      where: 'id = ?',
      whereArgs: [c.id],
    );
  }

  Future<int> delete(int id) async {
    final database = await db;
    return database.delete(_table, where: 'id = ?', whereArgs: [id]);
  }
}
