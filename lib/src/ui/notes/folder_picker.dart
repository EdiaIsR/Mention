import 'package:flutter/material.dart';

import '../../data/folder_repository.dart';
import '../../domain/folder.dart';

/// Résultat du sélecteur : [folderId] nul = racine.
/// (Une classe dédiée distingue « annulé » de « racine choisie ».)
class FolderChoice {
  const FolderChoice(this.folderId);
  final String? folderId;
}

/// Ouvre un sélecteur de dossier et renvoie le choix, ou nul si annulé.
/// [excludeId] masque un dossier (on ne déplace pas un dossier dans lui-même).
Future<FolderChoice?> pickFolder(
  BuildContext context,
  FolderRepository repository, {
  String? excludeId,
}) async {
  final all = await repository.getAll();
  if (!context.mounted) return null;

  // Chemin lisible « Idées / Projet X » pour chaque dossier.
  final byId = {for (final f in all) f.id: f};
  String pathOf(Folder f) {
    final parts = <String>[f.name];
    var current = f;
    while (current.parentId != null) {
      final parent = byId[current.parentId];
      if (parent == null) break;
      parts.insert(0, parent.name);
      current = parent;
    }
    return parts.join(' / ');
  }

  final entries = all.where((f) => f.id != excludeId).toList()
    ..sort((a, b) => pathOf(a).compareTo(pathOf(b)));

  return showDialog<FolderChoice>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Déplacer vers'),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, const FolderChoice(null)),
          child: const Row(children: [
            Icon(Icons.home_outlined),
            SizedBox(width: 12),
            Text('Racine'),
          ]),
        ),
        for (final f in entries)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, FolderChoice(f.id)),
            child: Row(children: [
              const Icon(Icons.folder_outlined),
              const SizedBox(width: 12),
              Expanded(child: Text(pathOf(f))),
            ]),
          ),
      ],
    ),
  );
}

/// Dialogue de saisie d'un nom (création ou renommage de dossier).
Future<String?> promptName(
  BuildContext context, {
  required String title,
  String initial = '',
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('Valider'),
        ),
      ],
    ),
  );
}

/// Confirmation de suppression. Renvoie true si confirmé.
Future<bool> confirmDelete(BuildContext context, String message) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Supprimer'),
        ),
      ],
    ),
  );
  return ok ?? false;
}
