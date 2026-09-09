import 'package:flutter/material.dart';

import '../../domain/note.dart';
import '../format.dart';

/// Consultation d'une note. Lecture seule au lot 1 ;
/// l'édition et le déplacement arrivent au lot 2.
class NoteDetailPage extends StatelessWidget {
  const NoteDetailPage({super.key, required this.note});

  final Note note;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(formatNoteDate(note.createdAt))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          note.rawText,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
