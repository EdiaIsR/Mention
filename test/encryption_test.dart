import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mention/src/data/database.dart';
import 'package:path/path.dart' as p;

/// Preuve que la base au repos est bien chiffrée par SQLCipher :
/// sans la clé (ou avec une mauvaise clé), le fichier est illisible.
void main() {
  test('le fichier est illisible sans la bonne clé', () async {
    final dir = Directory.systemTemp.createTempSync('mention_test');
    final file = File(p.join(dir.path, 'enc.db'));
    addTearDown(() => dir.deleteSync(recursive: true));

    Future<AppDatabase> openWith(String key) async => AppDatabase(
          NativeDatabase(file, setup: (db) => applyEncryptionKey(db, key)),
        );

    // Écriture avec la bonne clé.
    var db = await openWith('bonne-cle');
    await db.into(db.notes).insert(NotesCompanion.insert(
          id: 'n1',
          rawText: 'secret',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
    await db.close();

    // Relecture avec la bonne clé : OK.
    db = await openWith('bonne-cle');
    expect(await db.select(db.notes).get(), hasLength(1));
    await db.close();

    // Mauvaise clé : SQLCipher refuse de lire.
    final wrong = await openWith('mauvaise-cle');
    await expectLater(wrong.select(wrong.notes).get(), throwsA(anything));
    await wrong.close();

    // Le fichier ne contient pas le texte en clair.
    final bytes = file.readAsBytesSync();
    expect(String.fromCharCodes(bytes).contains('secret'), isFalse);
    // Un fichier SQLite non chiffré commencerait par "SQLite format 3".
    expect(String.fromCharCodes(bytes.take(15)), isNot('SQLite format 3'));
  });
}
