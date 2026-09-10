import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mention/src/data/database.dart';
import 'package:mention/src/data/note_repository.dart';
import 'package:mention/src/domain/llm/enrichment_service.dart';
import 'package:mention/src/domain/llm/fake_llm_provider.dart';
import 'package:mention/src/domain/llm/llm_provider.dart';
import 'package:mention/src/domain/note.dart';

/// Fournisseur scripté pour tester la validation stricte et la relance.
class _ScriptedProvider implements LlmProvider {
  _ScriptedProvider(this.outputs);
  final List<String> outputs;
  int calls = 0;

  @override
  Future<String> reformulate(String rawText) async {
    calls++;
    return outputs.removeAt(0);
  }

  @override
  Future<String> summarize(String rawText) async => reformulate(rawText);
}

void main() {
  late AppDatabase db;
  late NoteRepository notes;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    notes = NoteRepository(db);
  });

  tearDown(() => db.close());

  test('succès : le résultat est stocké, rawText intact', () async {
    final service = EnrichmentService(provider: FakeLlmProvider(), notes: notes);
    final note = (await notes.create('texte dicté brut'))!;

    final outcome = await service.request(note, EnrichmentKind.reformulate);

    expect(outcome, EnrichmentOutcome.done);
    final updated = (await notes.getById(note.id))!;
    expect(updated.rawText, 'texte dicté brut');
    expect(updated.refinedText, contains('texte dicté brut'));
    expect(updated.pendingOp, isNull);
  });

  test('indisponible : mise en attente, puis reprise quand ça revient',
      () async {
    final provider = FakeLlmProvider(available: false);
    final service = EnrichmentService(provider: provider, notes: notes);
    final note = (await notes.create('note hors ligne'))!;

    final outcome = await service.request(note, EnrichmentKind.summarize);
    expect(outcome, EnrichmentOutcome.queued);
    expect((await notes.getById(note.id))!.pendingOp, EnrichmentKind.summarize);

    // Le réseau revient : la reprise traite la file.
    provider.available = true;
    await service.retryPending();
    final updated = (await notes.getById(note.id))!;
    expect(updated.summaryText, isNotNull);
    expect(updated.pendingOp, isNull);
  });

  test('sortie inexploitable : une seule relance puis abandon propre',
      () async {
    final provider = _ScriptedProvider(['   ', '']);
    final service = EnrichmentService(provider: provider, notes: notes);
    final note = (await notes.create('note maudite'))!;

    final outcome = await service.request(note, EnrichmentKind.reformulate);

    expect(outcome, EnrichmentOutcome.failed);
    expect(provider.calls, 2); // relance unique
    final updated = (await notes.getById(note.id))!;
    expect(updated.refinedText, isNull);
    expect(updated.pendingOp, isNull);
    expect(updated.rawText, 'note maudite');
  });

  test('relance qui aboutit : la seconde sortie est acceptée', () async {
    final provider = _ScriptedProvider(['', 'version propre']);
    final service = EnrichmentService(provider: provider, notes: notes);
    final note = (await notes.create('note sauvée'))!;

    final outcome = await service.request(note, EnrichmentKind.reformulate);

    expect(outcome, EnrichmentOutcome.done);
    expect((await notes.getById(note.id))!.refinedText, 'version propre');
  });

  test('retryPending s\'arrête si le fournisseur retombe indisponible',
      () async {
    final provider = FakeLlmProvider(available: false);
    final service = EnrichmentService(provider: provider, notes: notes);
    final a = (await notes.create('attente A'))!;
    final b = (await notes.create('attente B'))!;
    await service.request(a, EnrichmentKind.reformulate);
    await service.request(b, EnrichmentKind.reformulate);

    // Toujours indisponible : la reprise n'insiste pas et ne perd rien.
    await service.retryPending();
    expect(await notes.getPending(), hasLength(2));
  });
}
