/// Enrichissement LLM demandé sur une note.
enum EnrichmentKind {
  reformulate('reformulate'),
  summarize('summarize');

  const EnrichmentKind(this.dbValue);
  final String dbValue;

  static EnrichmentKind? fromDb(String? value) => switch (value) {
        'reformulate' => reformulate,
        'summarize' => summarize,
        _ => null,
      };
}

/// Une note capturée (dictée ou saisie). [rawText] est le texte brut,
/// jamais altéré par les traitements LLM : [refinedText] et [summaryText]
/// s'ajoutent à côté, à la demande de l'utilisateur uniquement.
class Note {
  const Note({
    required this.id,
    required this.rawText,
    required this.createdAt,
    required this.updatedAt,
    this.folderId,
    this.refinedText,
    this.summaryText,
    this.pendingOp,
  });

  final String id;
  final String rawText;
  final String? folderId;
  final String? refinedText;
  final String? summaryText;

  /// Enrichissement en attente (réseau ou quota indisponible au moment
  /// de la demande) ; sera repris automatiquement.
  final EnrichmentKind? pendingOp;

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
