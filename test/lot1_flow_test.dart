import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mention/src/app.dart';
import 'package:mention/src/data/database.dart';
import 'package:mention/src/data/folder_repository.dart';
import 'package:mention/src/data/note_repository.dart';
import 'package:mention/src/domain/dictation/fake_dictation_engine.dart';
import 'package:mention/src/domain/llm/enrichment_service.dart';
import 'package:mention/src/domain/llm/fake_llm_provider.dart';

/// Parcours complets du lot 1 : dicter → retrouver, saisir → retrouver,
/// interruption → rien de perdu.
void main() {
  late AppDatabase db;
  late NoteRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = NoteRepository(db);
  });


  tearDown(() => db.close());

  Widget app(FakeDictationEngine engine) => MentionApp(
        dictationEngine: engine,
        noteRepository: repo,
        folderRepository: FolderRepository(db),
        enrichmentService:
            EnrichmentService(provider: FakeLlmProvider(), notes: repo),
      );

  /// Démonte l'app avant la fin du test : purge le micro-timer que Drift
  /// programme quand un flux de requête perd son dernier abonné, sans quoi
  /// testWidgets échoue sur « Pending timers ».
  Future<void> unmountApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    // Durée non nulle obligatoire : sans elle l'horloge simulée n'avance pas
    // et le timer à durée nulle de Drift ne se déclenche jamais.
    await tester.pump(const Duration(milliseconds: 1));
  }


  testWidgets('dicter, arrêter, retrouver la note dans la liste',
      (tester) async {
    final engine = FakeDictationEngine(
      sentence: 'penser à arroser les plantes',
      wordInterval: const Duration(milliseconds: 100),
    );
    await tester.pumpWidget(app(engine));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.mic));
    await tester.pump(); // construit la page de dictée, l'écoute démarre
    // 400 ms : la transition de page (300 ms) est finie — le bouton stop est
    // en place et cliquable — et 4 des 5 mots ont été transcrits.
    await tester.pump(const Duration(milliseconds: 400));
    // Frame supplémentaire : la route retire son IgnorePointer de transition,
    // le bouton stop devient cliquable.
    await tester.pump();
    expect(find.textContaining('penser à'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.stop));
    await tester.pumpAndSettle();

    // Retour à la liste : la note dictée (partielle) y figure.
    expect(find.textContaining('penser à'), findsOneWidget);
    final notes = await repo.getAll();
    expect(notes, hasLength(1));
    expect(notes.single.rawText, startsWith('penser à'));
    await unmountApp(tester);
  });

  testWidgets('la fin de session du moteur enregistre sans geste (interruption)',
      (tester) async {
    final engine = FakeDictationEngine(
      sentence: 'idée avant interruption',
      // Assez lent pour que la session se termine après la transition de
      // page : fermer une page pendant sa transition d'ouverture coince
      // le banc de test.
      wordInterval: const Duration(milliseconds: 150),
    );
    await tester.pumpWidget(app(engine));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.mic));
    await tester.pump(); // construit la page de dictée, l'écoute démarre
    // On laisse le moteur aller au bout de la phrase (450 ms) : le flux se
    // ferme seul, comme lors d'une limite de durée ou d'un appel entrant.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    final notes = await repo.getAll();
    expect(notes, hasLength(1));
    expect(notes.single.rawText, 'idée avant interruption');
    await unmountApp(tester);
  });

  testWidgets('saisir une note au clavier et la consulter', (tester) async {
    await tester.pumpWidget(app(FakeDictationEngine()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextField), 'Courses\npain, lait, œufs');
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    expect(find.text('Courses'), findsOneWidget);

    await tester.tap(find.text('Courses'));
    await tester.pumpAndSettle();
    expect(find.textContaining('pain, lait, œufs'), findsOneWidget);
    await unmountApp(tester);
  });

  testWidgets('une dictée sans un mot ne crée pas de note vide',
      (tester) async {
    final engine = FakeDictationEngine(
      sentence: 'jamais émis',
      wordInterval: const Duration(minutes: 1),
    );
    await tester.pumpWidget(app(engine));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.mic));
    // Le moteur (1 mot/minute) n'émet rien : pumpAndSettle attend simplement
    // la fin des animations d'ouverture, puis le bouton stop est cliquable.
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.stop));
    await tester.pumpAndSettle();

    expect(await repo.getAll(), isEmpty);
    await unmountApp(tester);
  });
}
