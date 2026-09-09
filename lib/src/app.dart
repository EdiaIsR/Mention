import 'package:flutter/material.dart';

import 'data/note_repository.dart';
import 'domain/dictation/dictation_engine.dart';
import 'ui/notes/notes_list_page.dart';

class MentionApp extends StatelessWidget {
  const MentionApp({
    super.key,
    required this.dictationEngine,
    required this.noteRepository,
  });

  final DictationEngine dictationEngine;
  final NoteRepository noteRepository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mention',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: NotesListPage(repository: noteRepository, engine: dictationEngine),
    );
  }
}
