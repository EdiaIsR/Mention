import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

part 'database.g.dart';

/// Table des notes. La classe générée s'appelle NoteRow pour laisser le nom
/// Note au modèle du domaine (lib/src/domain/note.dart).
@DataClassName('NoteRow')
class Notes extends Table {
  TextColumn get id => text()();
  TextColumn get rawText => text()();
  TextColumn get folderId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(tables: [Notes])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;
}

/// Ouvre la base chiffrée dans le répertoire de données de l'app.
///
/// Le moteur est SQLCipher sur toutes les plateformes : le hook déclaré dans
/// pubspec.yaml (`sqlite3 → source: sqlcipher`) remplace SQLite par SQLCipher
/// dans le binaire embarqué.
QueryExecutor openEncryptedDatabase({required String key}) {
  return LazyDatabase(() async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'mention.db'));
    return NativeDatabase.createInBackground(
      file,
      setup: (db) => applyEncryptionKey(db, key),
    );
  });
}

/// PRAGMA key, à exécuter avant toute requête sur une connexion SQLCipher.
void applyEncryptionKey(sqlite.Database db, String key) {
  final escaped = key.replaceAll("'", "''");
  db.execute("PRAGMA key = '$escaped';");
}
