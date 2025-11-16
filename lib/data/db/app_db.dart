// ignore_for_file: depend_on_referenced_packages

import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_db.g.dart';

class Credentials extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get title => text()(); // encrypted
  TextColumn get username => text()(); // encrypted
  TextColumn get password => text()(); // encrypted
  TextColumn get notes => text().nullable()(); // encrypted
  TextColumn get category => text().nullable()(); // encrypted
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final folder = await getApplicationDocumentsDirectory();
    final file = File(p.join(folder.path, 'vault.sqlite'));

    // Drift uses platform SQLite (sqlite3_flutter_libs required)
    return NativeDatabase(file);
  });
}

@DriftDatabase(tables: [Credentials])
class AppDb extends _$AppDb {
  AppDb() : super(_openConnection());

  @override
  int get schemaVersion => 1;
}
