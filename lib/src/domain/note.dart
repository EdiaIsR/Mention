/// Une note capturée (dictée ou saisie). [rawText] est le texte brut,
/// jamais altéré par les traitements LLM (qui arriveront au lot 3
/// dans des champs séparés).
class Note {
  const Note({
    required this.id,
    required this.rawText,
    required this.createdAt,
    required this.updatedAt,
    this.folderId,
  });

  final String id;
  final String rawText;
  final String? folderId;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Première ligne non vide, pour l'affichage en liste.
  String get excerpt {
    final line = rawText
        .split('\n')
        .map((l) => l.trim())
        .firstWhere((l) => l.isNotEmpty, orElse: () => '');
    return line.length <= 80 ? line : '${line.substring(0, 80)}…';
  }
}
