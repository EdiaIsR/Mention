import 'package:flutter/material.dart';

import '../../data/note_repository.dart';

/// Saisie d'une note au clavier — le mode principal sur PC, où la
/// reconnaissance vocale iOS n'existe pas.
class TypeNotePage extends StatefulWidget {
  const TypeNotePage({super.key, required this.repository, this.folderId});

  final NoteRepository repository;

  /// Dossier de destination de la note (nul = racine).
  final String? folderId;

  @override
  State<TypeNotePage> createState() => _TypeNotePageState();
}

class _TypeNotePageState extends State<TypeNotePage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await widget.repository
        .create(_controller.text, folderId: widget.folderId);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouvelle note'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Enregistrer',
            onPressed: _save,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: _controller,
          autofocus: true,
          maxLines: null,
          expands: true,
          textAlignVertical: TextAlignVertical.top,
          decoration: const InputDecoration(
            hintText: 'Écris ta note…',
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }
}
