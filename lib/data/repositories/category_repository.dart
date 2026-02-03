// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
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
          'name': 'Passwords',
          'iconKey': 'lock',
          'colorValue': 0xFF3B82F6,
        });
        await db.insert(_table, {
          'name': 'Bank Cards',
          'iconKey': 'credit_card',
          'colorValue': 0xFF8B5CF6,
        });
        await db.insert(_table, {
          'name': 'Secure Notes',
          'iconKey': 'note',
          'colorValue': 0xFFF97316,
        });
        await db.insert(_table, {
          'name': 'ID Documents',
          'iconKey': 'id',
          'colorValue': 0xFF10B981,
        });
        await db.insert(_table, {
          'name': 'Bank Accounts',
          'iconKey': 'bank',
          'colorValue': 0xFF06B6D4,
        });
      },
    );
  }

  Future<List<VaultCategory>> getAll() async {
    final database = await db;
    final rows = await database.query(_table, orderBy: 'name COLLATE NOCASE');
    return rows.map((r) => VaultCategory.fromMap(r)).toList();
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
