import 'package:flutter/material.dart';

import 'data/folder_repository.dart';
import 'data/note_repository.dart';
import 'domain/dictation/dictation_engine.dart';
import 'ui/notes/folder_page.dart';

class MentionApp extends StatelessWidget {
  const MentionApp({
    super.key,
    required this.dictationEngine,
    required this.noteRepository,
    required this.folderRepository,
  });

  final DictationEngine dictationEngine;
  final NoteRepository noteRepository;
  final FolderRepository folderRepository;

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
      ),
    );
  }
}
