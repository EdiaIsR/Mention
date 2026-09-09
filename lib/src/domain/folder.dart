/// Un dossier de l'arborescence. [parentId] nul = dossier racine.
class Folder {
  const Folder({
    required this.id,
    required this.name,
    this.parentId,
    this.position = 0,
  });

  final String id;
  final String name;
  final String? parentId;
  final int position;
}
