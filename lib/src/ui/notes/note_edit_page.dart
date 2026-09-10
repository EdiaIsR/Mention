import 'package:flutter/material.dart';

import '../../data/folder_repository.dart';
import '../../data/note_repository.dart';
import '../../domain/llm/enrichment_service.dart';
import '../../domain/note.dart';
import '../format.dart';
import 'folder_picker.dart';

/// Consultation et édition d'une note. La coche enregistre le texte brut ;
/// le menu permet de la déplacer, la supprimer, la reformuler ou la
/// synthétiser. Les versions enrichies s'affichent sous le texte brut,
/// qui reste toujours premier et éditable.
class NoteEditPage extends StatefulWidget {
  const NoteEditPage({
    super.key,
    required this.note,
    required this.noteRepository,
    required this.folderRepository,
    required this.enrichmentService,
  });

  final Note note;
  final NoteRepository noteRepository;
  final FolderRepository folderRepository;
  final EnrichmentService enrichmentService;

  @override
  State<NoteEditPage> createState() => _NoteEditPageState();
}

class _NoteEditPageState extends State<NoteEditPage> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.note.rawText);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await widget.noteRepository.updateRawText(widget.note.id, _controller.text);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _enrich(EnrichmentKind kind) async {
    // Enregistre d'abord le texte courant pour enrichir ce que l'utilisateur
    // a sous les yeux, pas une version antérieure.
    await widget.noteRepository.updateRawText(widget.note.id, _controller.text);
    final note = await widget.noteRepository.getById(widget.note.id);
    if (note == null) return;
    final outcome = await widget.enrichmentService.request(note, kind);
    if (!mounted) return;
    final message = switch (outcome) {
      EnrichmentOutcome.done => null,
      EnrichmentOutcome.queued =>
        'Hors ligne ou quota épuisé : la demande est en attente, '
            'elle sera reprise automatiquement.',
      EnrichmentOutcome.failed =>
        'Réponse inexploitable du service. Réessaie plus tard.',
    };
    if (message != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(formatNoteDate(widget.note.createdAt)),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Enregistrer',
            onPressed: _save,
          ),
          PopupMenuButton<String>(
            onSelected: (action) async {
              switch (action) {
                case 'reformulate':
                  await _enrich(EnrichmentKind.reformulate);
                case 'summarize':
                  await _enrich(EnrichmentKind.summarize);
                case 'move':
                  final choice =
                      await pickFolder(context, widget.folderRepository);
                  if (choice != null) {
                    await widget.noteRepository
                        .moveToFolder(widget.note.id, choice.folderId);
                  }
                case 'delete':
                  final ok = await confirmDelete(
                      context, 'Supprimer définitivement cette note ?');
                  if (ok) {
                    await widget.noteRepository.delete(widget.note.id);
                    if (context.mounted) Navigator.of(context).pop();
                  }
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'reformulate', child: Text('Reformuler')),
              PopupMenuItem(value: 'summarize', child: Text('Synthétiser')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'move', child: Text('Déplacer')),
              PopupMenuItem(value: 'delete', child: Text('Supprimer')),
            ],
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(border: InputBorder.none),
              ),
            ),
          ),
          // Versions enrichies et état d'attente, mis à jour en direct.
          StreamBuilder<Note?>(
            stream: widget.noteRepository.watchById(widget.note.id),
            builder: (context, snapshot) {
              final note = snapshot.data;
              if (note == null) return const SizedBox.shrink();
              final sections = <Widget>[
                if (note.pendingOp != null)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.hourglass_empty),
                    title: Text(note.pendingOp == EnrichmentKind.reformulate
                        ? 'Reformulation en attente'
                        : 'Synthèse en attente'),
                  ),
                if (note.refinedText != null)
                  _VersionCard(title: 'Reformulé', text: note.refinedText!),
                if (note.summaryText != null)
                  _VersionCard(title: 'Synthèse', text: note.summaryText!),
              ];
              if (sections.isEmpty) return const SizedBox.shrink();
              return ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.4,
                ),
                child: ListView(shrinkWrap: true, children: sections),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _VersionCard extends StatelessWidget {
  const _VersionCard({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            SelectableText(text),
          ],
        ),
      ),
    );
  }
}
