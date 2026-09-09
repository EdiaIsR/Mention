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

/// Table des dossiers. parentId nul = racine.
@DataClassName('FolderRow')
class Folders extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get parentId => text().nullable()();
  IntColumn get position => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(tables: [Notes, Folders])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seedDefaultFolders();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // v1 → v2 : la table notes existe déjà et n'est pas touchée.
            await m.createTable(folders);
            await _seedDefaultFolders();
          }
        },
      );

  /// Arborescence par défaut du cadrage (hors « Boîte de réception »,
  /// qui est virtuelle : les notes non classées vivent à la racine).
  /// Identifiants fixes pour rester stables d'une installation à l'autre.
  Future<void> _seedDefaultFolders() async {
    const defaults = [
      ('f-taches', 'Tâches', 0),
      ('f-listes', 'Listes', 1),
      ('f-idees', 'Idées', 2),
      ('f-pensees', 'Pensées', 3),
    ];
    for (final (id, name, position) in defaults) {
      await into(folders).insert(FoldersCompanion.insert(
        id: id,
        name: name,
        position: Value(position),
      ));
    }
  }
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
