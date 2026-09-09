import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mention/src/data/database.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

/// Preuve que la migration v1 → v2 préserve les notes existantes.
/// La base v1 est fabriquée en SQL brut, à l'identique du schéma généré
/// par Drift au lot 1.
void main() {
  test('une base v1 survit à la migration v2 et reçoit les dossiers', () async {
    final dir = Directory.systemTemp.createTempSync('mention_migration');
    final file = File(p.join(dir.path, 'v1.db'));
    addTearDown(() => dir.deleteSync(recursive: true));

    // Base v1 : table notes seule, user_version = 1.
    final raw = sqlite.sqlite3.open(file.path);
    raw
      ..execute('''
        CREATE TABLE notes (
          id TEXT NOT NULL,
          raw_text TEXT NOT NULL,
          folder_id TEXT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          PRIMARY KEY (id)
        );
      ''')
      ..execute(
          "INSERT INTO notes VALUES ('n1', 'note du lot 1', NULL, 1000, 1000);")
      ..execute('PRAGMA user_version = 1;')
      ..close();

    // Ouverture avec le schéma v2 : la migration doit se dérouler.
    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);

    final notes = await db.select(db.notes).get();
    expect(notes, hasLength(1));
    expect(notes.single.rawText, 'note du lot 1');

    final folders = await db.select(db.folders).get();
    expect(folders.map((f) => f.name).toSet(),
        {'Tâches', 'Listes', 'Idées', 'Pensées'});

    // La version enregistrée est bien passée à 2.
    final version = await db
        .customSelect('PRAGMA user_version;')
        .getSingle()
        .then((row) => row.data.values.first);
    expect(version, 2);
  });
}
