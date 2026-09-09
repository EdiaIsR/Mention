import 'package:flutter/material.dart';

import '../../data/folder_repository.dart';
import '../../data/note_repository.dart';
import '../../domain/note.dart';
import '../format.dart';
import 'folder_picker.dart';

/// Consultation et édition d'une note. La coche enregistre ;
/// le menu permet de la déplacer ou de la supprimer.
class NoteEditPage extends StatefulWidget {
  const NoteEditPage({
    super.key,
    required this.note,
    required this.noteRepository,
    required this.folderRepository,
  });

  final Note note;
  final NoteRepository noteRepository;
  final FolderRepository folderRepository;

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
              PopupMenuItem(value: 'move', child: Text('Déplacer')),
              PopupMenuItem(value: 'delete', child: Text('Supprimer')),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: _controller,
          maxLines: null,
          expands: true,
          textAlignVertical: TextAlignVertical.top,
          decoration: const InputDecoration(border: InputBorder.none),
        ),
      ),
    );
  }
}
