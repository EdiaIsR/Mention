import 'package:flutter/material.dart';

import 'data/folder_repository.dart';
import 'data/note_repository.dart';
import 'domain/dictation/dictation_engine.dart';
import 'domain/llm/enrichment_service.dart';
import 'ui/notes/folder_page.dart';

class MentionApp extends StatelessWidget {
  const MentionApp({
    super.key,
    required this.dictationEngine,
    required this.noteRepository,
    required this.folderRepository,
    required this.enrichmentService,
  });

  final DictationEngine dictationEngine;
  final NoteRepository noteRepository;
  final FolderRepository folderRepository;
  final EnrichmentService enrichmentService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mention',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: FolderPage(
        folderRepository: folderRepository,
        noteRepository: noteRepository,
        engine: dictationEngine,
        enrichmentService: enrichmentService,
      ),
    );
  }
}
