import 'package:flutter/material.dart';

import '../../data/folder_repository.dart';
import '../../data/note_repository.dart';
import '../../domain/llm/enrichment_service.dart';
import '../../domain/note.dart';
import '../format.dart';
import 'note_edit_page.dart';

/// Recherche plein texte dans toutes les notes.
class SearchPage extends StatefulWidget {
  const SearchPage({
    super.key,
    required this.noteRepository,
    required this.folderRepository,
    required this.enrichmentService,
  });

  final NoteRepository noteRepository;
  final FolderRepository folderRepository;
  final EnrichmentService enrichmentService;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  List<Note> _results = [];
  String _query = '';

  Future<void> _search(String query) async {
    _query = query;
    final results = await widget.noteRepository.search(query);
    // Ignore les résultats d'une frappe déjà dépassée.
    if (mounted && query == _query) setState(() => _results = results);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          autofocus: true,
          onChanged: _search,
          decoration: const InputDecoration(
            hintText: 'Rechercher…',
            border: InputBorder.none,
          ),
        ),
      ),
      body: _results.isEmpty
          ? Center(
              child: Text(_query.trim().isEmpty
                  ? 'Tape pour chercher dans toutes les notes.'
                  : 'Aucun résultat.'),
            )
          : ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, i) {
                final note = _results[i];
                return ListTile(
                  title: Text(note.excerpt,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(formatNoteDate(note.createdAt)),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => NoteEditPage(
                        note: note,
                        noteRepository: widget.noteRepository,
                        folderRepository: widget.folderRepository,
                        enrichmentService: widget.enrichmentService,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
