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

  test('supprimer un dossier détruit tout son sous-arbre, et rien d\'autre',
      () async {
    final sub = await folders.create('Sous-projet', parentId: 'f-idees');
    final inFolder = await notes.create('idée sacrifiée', folderId: 'f-idees');
    final inSub = await notes.create('détail sacrifié', folderId: sub!.id);
    final elsewhere = await notes.create('note épargnée', folderId: 'f-taches');
    await folders.create('Petit-fils', parentId: sub.id);

    // Le décompte annoncé avant suppression est exact.
    final content = await folders.countContent('f-idees');
    expect(content.notes, 2);
    expect(content.folders, 2); // Sous-projet + Petit-fils

    await folders.delete('f-idees');

    expect(await folders.getById('f-idees'), isNull);
    expect(await folders.getById(sub.id), isNull);
    expect(await notes.getById(inFolder!.id), isNull);
    expect(await notes.getById(inSub!.id), isNull);
    // Le reste de la base est intact.
    expect((await notes.getById(elsewhere!.id))!.rawText, 'note épargnée');
    expect((await folders.getAll()).map((f) => f.name),
        containsAll(['Tâches', 'Listes', 'Pensées']));
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
