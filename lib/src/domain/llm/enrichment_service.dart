import '../../data/note_repository.dart';
import '../note.dart';
import 'llm_provider.dart';

/// Résultat d'une demande d'enrichissement, du point de vue de l'UI.
enum EnrichmentOutcome {
  /// Résultat obtenu et enregistré.
  done,

  /// Fournisseur indisponible : la demande est en attente, elle sera
  /// reprise automatiquement. La note n'est pas bloquée pour autant.
  queued,

  /// Sortie du fournisseur inexploitable malgré la relance. Abandon propre.
  failed,
}

/// Orchestration des enrichissements LLM : appel, validation stricte,
/// une seule relance, mise en attente hors ligne et reprise.
/// Ne touche jamais à rawText.
class EnrichmentService {
  EnrichmentService({required this.provider, required this.notes});

  final LlmProvider provider;
  final NoteRepository notes;

  /// Demande un enrichissement pour [note]. Jamais d'exception : tout état
  /// d'erreur est traduit en [EnrichmentOutcome].
  Future<EnrichmentOutcome> request(Note note, EnrichmentKind kind) async {
    try {
      final result = await _callValidated(note.rawText, kind);
      await notes.setEnrichment(note.id, kind, result);
      return EnrichmentOutcome.done;
    } on LlmUnavailableException {
      await notes.setPendingOp(note.id, kind);
      return EnrichmentOutcome.queued;
    } on LlmBadOutputException {
      await notes.setPendingOp(note.id, null);
      return EnrichmentOutcome.failed;
    }
  }

  /// Reprend toutes les demandes en attente (au lancement de l'app,
  /// ou quand le réseau revient). S'arrête au premier signe
  /// d'indisponibilité : inutile d'insister sur les suivantes.
  Future<void> retryPending() async {
    for (final note in await notes.getPending()) {
      final kind = note.pendingOp;
      if (kind == null) continue;
      final outcome = await request(note, kind);
      if (outcome == EnrichmentOutcome.queued) return;
    }
  }

  /// Appelle le fournisseur avec validation stricte de la sortie et une
  /// seule relance en cas de réponse inexploitable.
  Future<String> _callValidated(String rawText, EnrichmentKind kind) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      final output = switch (kind) {
        EnrichmentKind.reformulate => await provider.reformulate(rawText),
        EnrichmentKind.summarize => await provider.summarize(rawText),
      };
      final cleaned = output.trim();
      if (_isUsable(cleaned)) return cleaned;
    }
    throw const LlmBadOutputException('sortie vide ou aberrante après relance');
  }

  /// Garde-fous minimaux : non vide, et pas démesurément plus long que
  /// l'entrée (un LLM qui divague produit souvent des pavés hors sujet).
  bool _isUsable(String output) => output.isNotEmpty && output.length < 20000;
}
