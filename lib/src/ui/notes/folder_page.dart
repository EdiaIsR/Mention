import 'package:flutter/material.dart';

import '../../data/folder_repository.dart';
import '../../data/note_repository.dart';
import '../../domain/dictation/dictation_engine.dart';
import '../../domain/folder.dart';
import '../../domain/note.dart';
import '../format.dart';
import 'dictation_page.dart';
import 'folder_picker.dart';
import 'note_edit_page.dart';
import 'search_page.dart';
import 'type_note_page.dart';

/// Navigation dans l'arborescence : un écran par dossier.
/// [folder] nul = racine (dossiers de premier niveau + notes non classées).
class FolderPage extends StatelessWidget {
  const FolderPage({
    super.key,
    this.folder,
    required this.folderRepository,
    required this.noteRepository,
    required this.engine,
  });

  final Folder? folder;
  final FolderRepository folderRepository;
  final NoteRepository noteRepository;
  final DictationEngine engine;

  String? get _folderId => folder?.id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(folder?.name ?? 'Mention'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Rechercher',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SearchPage(
                  noteRepository: noteRepository,
                  folderRepository: folderRepository,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined),
            tooltip: 'Nouveau dossier',
            onPressed: () async {
              final name =
                  await promptName(context, title: 'Nouveau dossier');
              if (name != null) {
                await folderRepository.create(name, parentId: _folderId);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Nouvelle note au clavier',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => TypeNotePage(
                  repository: noteRepository,
                  folderId: _folderId,
                ),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Folder>>(
        stream: folderRepository.watchChildren(_folderId),
        builder: (context, folderSnap) {
          return StreamBuilder<List<Note>>(
            stream: noteRepository.watchByFolder(_folderId),
            builder: (context, noteSnap) {
              final subFolders = folderSnap.data;
              final notes = noteSnap.data;
              if (subFolders == null || notes == null) {
                return const Center(child: CircularProgressIndicator());
              }
              if (subFolders.isEmpty && notes.isEmpty) {
                return const Center(
                  child: Text('Rien ici pour l\'instant.',
                      textAlign: TextAlign.center),
                );
              }
              return ListView(
                children: [
                  for (final f in subFolders) _folderTile(context, f),
                  if (subFolders.isNotEmpty && notes.isNotEmpty)
                    const Divider(height: 1),
                  for (final n in notes) _noteTile(context, n),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Dicter une note',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => DictationPage(
              repository: noteRepository,
              engine: engine,
              folderId: _folderId,
            ),
          ),
        ),
        child: const Icon(Icons.mic),
      ),
    );
  }

  Widget _folderTile(BuildContext context, Folder f) {
    return ListTile(
      leading: const Icon(Icons.folder_outlined),
      title: Text(f.name),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => FolderPage(
            folder: f,
            folderRepository: folderRepository,
            noteRepository: noteRepository,
            engine: engine,
          ),
        ),
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (action) async {
          switch (action) {
            case 'rename':
              final name = await promptName(context,
                  title: 'Renommer le dossier', initial: f.name);
              if (name != null) await folderRepository.rename(f.id, name);
            case 'delete':
              final ok = await confirmDelete(
                  context,
                  'Supprimer « ${f.name} » ? Son contenu remontera '
                  'dans le dossier parent, rien ne sera perdu.');
              if (ok) await folderRepository.delete(f.id);
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'rename', child: Text('Renommer')),
          PopupMenuItem(value: 'delete', child: Text('Supprimer')),
        ],
      ),
    );
  }

  Widget _noteTile(BuildContext context, Note n) {
    return ListTile(
      title: Text(n.excerpt, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(formatNoteDate(n.createdAt)),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => NoteEditPage(
            note: n,
            noteRepository: noteRepository,
            folderRepository: folderRepository,
          ),
        ),
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (action) async {
          switch (action) {
            case 'move':
              final choice = await pickFolder(context, folderRepository);
              if (choice != null) {
                await noteRepository.moveToFolder(n.id, choice.folderId);
              }
            case 'delete':
              final ok = await confirmDelete(
                  context, 'Supprimer définitivement cette note ?');
              if (ok) await noteRepository.delete(n.id);
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'move', child: Text('Déplacer')),
          PopupMenuItem(value: 'delete', child: Text('Supprimer')),
        ],
      ),
    );
  }
}
