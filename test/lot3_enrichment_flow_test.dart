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

/// Parcours d'enrichissement (socle du lot 3, fournisseur simulé) :
/// reformuler depuis l'écran d'édition, brut conservé, cas hors ligne.
void main() {
  late AppDatabase db;
  late NoteRepository notes;
  late FakeLlmProvider provider;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    notes = NoteRepository(db);
    provider = FakeLlmProvider();
  });

  tearDown(() => db.close());

  Widget app() => MentionApp(
        dictationEngine: FakeDictationEngine(),
        noteRepository: notes,
        folderRepository: FolderRepository(db),
        enrichmentService:
            EnrichmentService(provider: provider, notes: notes),
      );

  // Voir JOURNAL.md : purge le micro-timer de fermeture des flux Drift.
  Future<void> unmountApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<void> openNoteAndSelect(WidgetTester tester, String action) async {
    await tester.tap(find.text('euh donc faut que je pense au truc'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(action));
    await tester.pumpAndSettle();
  }

  testWidgets('reformuler : la version s\'affiche, le brut reste',
      (tester) async {
    await notes.create('euh donc faut que je pense au truc');
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await openNoteAndSelect(tester, 'Reformuler');

    expect(find.text('Reformulé'), findsOneWidget);
    expect(find.textContaining('[Reformulé — simulation]'), findsOneWidget);
    // Le brut est intact, à l'écran comme en base.
    expect(find.text('euh donc faut que je pense au truc'), findsOneWidget);
    final stored = (await notes.getAll()).single;
    expect(stored.rawText, 'euh donc faut que je pense au truc');
    expect(stored.refinedText, isNotNull);
    await unmountApp(tester);
  });

  testWidgets('hors ligne : mise en attente visible, reprise au retour',
      (tester) async {
    provider.available = false;
    await notes.create('euh donc faut que je pense au truc');
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await openNoteAndSelect(tester, 'Synthétiser');

    // Signalement discret + état visible sur la note.
    expect(find.textContaining('en attente'), findsWidgets);
    expect(find.text('Synthèse en attente'), findsOneWidget);
    final pending = (await notes.getAll()).single;
    expect(pending.summaryText, isNull);

    // Le réseau revient : la reprise aboutit et l'écran se met à jour.
    provider.available = true;
    await EnrichmentService(provider: provider, notes: notes).retryPending();
    await tester.pumpAndSettle();
    expect(find.text('Synthèse'), findsOneWidget);
    expect(find.textContaining('[Synthèse — simulation]'), findsOneWidget);
    expect(find.text('Synthèse en attente'), findsNothing);
    await unmountApp(tester);
  });
}
