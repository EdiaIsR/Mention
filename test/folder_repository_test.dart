import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mention/src/data/database.dart';
import 'package:mention/src/data/folder_repository.dart';
import 'package:mention/src/data/note_repository.dart';

void main() {
  late AppDatabase db;
  late FolderRepository folders;
  late NoteRepository notes;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    folders = FolderRepository(db);
    notes = NoteRepository(db);
  });

  tearDown(() => db.close());

  test('les dossiers par défaut existent à la création', () async {
    final all = await folders.getAll();
    expect(all.map((f) => f.name).toList(),
        ['Tâches', 'Listes', 'Idées', 'Pensées']);
    expect(all.every((f) => f.parentId == null), isTrue);
  });

  test('créer, renommer, imbriquer', () async {
    final projet = await folders.create('Projet X', parentId: 'f-idees');
    expect(projet, isNotNull);
    expect(await folders.create('   '), isNull);

    await folders.rename(projet!.id, 'Projet Y');
    expect((await folders.getById(projet.id))!.name, 'Projet Y');

    final children = await folders.watchChildren('f-idees').first;
    expect(children.map((f) => f.name).toList(), ['Projet Y']);
  });

  test('supprimer un dossier fait remonter son contenu, sans rien détruire',
      () async {
    final sub = await folders.create('Sous-projet', parentId: 'f-idees');
    final note = await notes.create('idée précieuse', folderId: 'f-idees');
    await folders.create('Petit-fils', parentId: sub!.id);

    await folders.delete('f-idees');

    // La note remonte à la racine (parent de f-idees).
    expect((await notes.getById(note!.id))!.folderId, isNull);
    // Le sous-dossier remonte à la racine, son propre fils le suit.
    final rootFolders = await folders.watchChildren(null).first;
    expect(rootFolders.map((f) => f.name), contains('Sous-projet'));
    final grandChildren = await folders.watchChildren(sub.id).first;
    expect(grandChildren.map((f) => f.name).toList(), ['Petit-fils']);
  });

  test('déplacer et éditer une note', () async {
    final note = await notes.create('brouillon', folderId: null);
    await notes.moveToFolder(note!.id, 'f-pensees');
    expect((await notes.getById(note.id))!.folderId, 'f-pensees');

    await notes.updateRawText(note.id, 'brouillon corrigé');
    expect((await notes.getById(note.id))!.rawText, 'brouillon corrigé');

    // Une édition vide est ignorée : on ne peut pas vider une note.
    await notes.updateRawText(note.id, '  ');
    expect((await notes.getById(note.id))!.rawText, 'brouillon corrigé');

    await notes.delete(note.id);
    expect(await notes.getById(note.id), isNull);
  });

  test('recherche plein texte, y compris avec % et _', () async {
    await notes.create('acheter du pain complet');
    await notes.create('rendement à 100% du contrat');
    await notes.create('sans rapport');

    expect((await notes.search('pain')).single.rawText,
        'acheter du pain complet');
    expect((await notes.search('100%')).single.rawText,
        'rendement à 100% du contrat');
    expect(await notes.search('   '), isEmpty);
    expect(await notes.search('introuvable'), isEmpty);
  });
}
