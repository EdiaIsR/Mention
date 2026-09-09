import 'package:flutter/material.dart';

import '../../data/note_repository.dart';
import '../../domain/dictation/dictation_engine.dart';
import '../../domain/note.dart';
import '../format.dart';
import 'dictation_page.dart';
import 'note_detail_page.dart';
import 'type_note_page.dart';

/// Écran principal : liste des notes, la plus récente d'abord.
/// Micro = dictée ; crayon = saisie clavier (utile sur PC).
class NotesListPage extends StatelessWidget {
  const NotesListPage({
    super.key,
    required this.repository,
    required this.engine,
  });

  final NoteRepository repository;
  final DictationEngine engine;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mention'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Nouvelle note au clavier',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => TypeNotePage(repository: repository),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Note>>(
        stream: repository.watchAll(),
        builder: (context, snapshot) {
          final notes = snapshot.data;
          if (notes == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (notes.isEmpty) {
            return const Center(
              child: Text('Aucune note.\nDicte avec le micro ou écris avec le crayon.',
                  textAlign: TextAlign.center),
            );
          }
          return ListView.separated(
            itemCount: notes.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final note = notes[i];
              return ListTile(
                title: Text(note.excerpt,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(formatNoteDate(note.createdAt)),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => NoteDetailPage(note: note),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Dicter une note',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                DictationPage(repository: repository, engine: engine),
          ),
        ),
        child: const Icon(Icons.mic),
      ),
    );
  }
}
