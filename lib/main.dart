import 'dart:async';

import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/data/database.dart';
import 'src/data/folder_repository.dart';
import 'src/data/key_store.dart';
import 'src/data/note_repository.dart';
import 'src/domain/dictation/fake_dictation_engine.dart';
import 'src/domain/llm/enrichment_service.dart';
import 'src/domain/llm/fake_llm_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final key = await FileKeyStore().obtainDatabaseKey();
  final db = AppDatabase(openEncryptedDatabase(key: key));
  final noteRepository = NoteRepository(db);

  // Moteur de dictée et fournisseur LLM simulés pour l'instant.
  // iPhone : framework Speech au lot livraison iOS ; LLM réel au lot 3,
  // choisi par comparaison sur les dictées réelles de l'utilisateur.
  final enrichmentService = EnrichmentService(
    provider: FakeLlmProvider(),
    notes: noteRepository,
  );

  // Reprise des enrichissements restés en attente (hors ligne, quota).
  unawaited(enrichmentService.retryPending());

  runApp(MentionApp(
    dictationEngine: FakeDictationEngine(),
    noteRepository: noteRepository,
    folderRepository: FolderRepository(db),
    enrichmentService: enrichmentService,
  ));
}
