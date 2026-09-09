import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mention/src/app.dart';
import 'package:mention/src/data/database.dart';
import 'package:mention/src/data/folder_repository.dart';
import 'package:mention/src/data/note_repository.dart';
import 'package:mention/src/domain/dictation/fake_dictation_engine.dart';

/// Parcours du lot 2 : arborescence (créer, renommer, déplacer, supprimer)
/// et recherche, à travers l'UI.
void main() {
  late AppDatabase db;
  late NoteRepository notes;
  late FolderRepository folders;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    notes = NoteRepository(db);
    folders = FolderRepository(db);
  });

  tearDown(() => db.close());

  Widget app() => MentionApp(
        dictationEngine: FakeDictationEngine(),
        noteRepository: notes,
        folderRepository: folders,
      );

  // Voir JOURNAL.md : purge le micro-timer de fermeture des flux Drift.
  Future<void> unmountApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('la racine montre les dossiers par défaut', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    for (final name in ['Tâches', 'Listes', 'Idées', 'Pensées']) {
      expect(find.text(name), findsOneWidget);
    }
    await unmountApp(tester);
  });

  testWidgets('créer un dossier, y entrer, y écrire une note',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.create_new_folder_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Jardin');
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();
    expect(find.text('Jardin'), findsOneWidget);

    await tester.tap(find.text('Jardin'));
    await tester.pumpAndSettle();
    expect(find.text('Rien ici pour l\'instant.'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'tailler la haie');
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    expect(find.text('tailler la haie'), findsOneWidget);

    // La note est bien rattachée au dossier créé.
    final all = await notes.getAll();
    final jardin =
        (await folders.getAll()).firstWhere((f) => f.name == 'Jardin');
    expect(all.single.folderId, jardin.id);
    await unmountApp(tester);
  });

  testWidgets('renommer un dossier depuis son menu', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    // Menu du dossier « Tâches » (premier PopupMenuButton de la liste).
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Renommer'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'À faire');
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();

    expect(find.text('À faire'), findsOneWidget);
    expect(find.text('Tâches'), findsNothing);
    await unmountApp(tester);
  });

  testWidgets('déplacer une note vers un dossier via son menu',
      (tester) async {
    await notes.create('acheter des clous');
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('acheter des clous'), findsOneWidget);

    // La note est après les 4 dossiers : son menu est le 5e.
    await tester.tap(find.byType(PopupMenuButton<String>).at(4));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Déplacer'));
    await tester.pumpAndSettle();
    // « Listes » existe aussi dans la liste derrière le dialogue :
    // viser l'entrée du dialogue (dernière dans l'arbre).
    await tester.tap(find.text('Listes').last);
    await tester.pumpAndSettle();

    // Disparue de la racine, rattachée à Listes.
    expect(find.text('acheter des clous'), findsNothing);
    expect((await notes.getAll()).single.folderId, 'f-listes');
    await unmountApp(tester);
  });

  testWidgets('supprimer une note avec confirmation', (tester) async {
    await notes.create('note éphémère');
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>).at(4));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer').last); // bouton du dialogue
    await tester.pumpAndSettle();

    expect(find.text('note éphémère'), findsNothing);
    expect(await notes.getAll(), isEmpty);
    await unmountApp(tester);
  });

  testWidgets('supprimer un dossier plein : la confirmation annonce le contenu',
      (tester) async {
    await notes.create('dedans', folderId: 'f-idees');
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    Future<void> openDeleteDialog() async {
      // « Idées » est le 3e dossier de la racine.
      await tester.tap(find.byType(PopupMenuButton<String>).at(2));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();
    }

    await openDeleteDialog();
    expect(find.textContaining('1 note(s)'), findsOneWidget);

    // Annuler ne détruit rien.
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(find.text('Idées'), findsOneWidget);
    expect(await notes.getAll(), hasLength(1));

    // Confirmer détruit le dossier et son contenu.
    await openDeleteDialog();
    await tester.tap(find.text('Supprimer').last);
    await tester.pumpAndSettle();
    expect(find.text('Idées'), findsNothing);
    expect(await notes.getAll(), isEmpty);
    await unmountApp(tester);
  });

  testWidgets('éditer le texte d\'une note', (tester) async {
    await notes.create('texte initial');
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('texte initial'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'texte corrigé');
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    expect(find.text('texte corrigé'), findsOneWidget);
    expect((await notes.getAll()).single.rawText, 'texte corrigé');
    await unmountApp(tester);
  });

  testWidgets('rechercher une note et l\'ouvrir', (tester) async {
    await notes.create('la recette de la tarte aux pommes', folderId: 'f-idees');
    await notes.create('sans rapport');
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'tarte');
    await tester.pumpAndSettle();

    expect(find.textContaining('recette'), findsOneWidget);
    expect(find.text('sans rapport'), findsNothing);

    await tester.tap(find.textContaining('recette'));
    await tester.pumpAndSettle();
    expect(find.textContaining('tarte aux pommes'), findsOneWidget);
    await unmountApp(tester);
  });
}
