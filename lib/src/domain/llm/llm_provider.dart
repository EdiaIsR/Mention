/// Abstraction du fournisseur LLM (reformulation, synthèse, et plus tard
/// classement). Changer de fournisseur = changer une seule implémentation.
///
/// Contrat d'erreurs :
/// - [LlmUnavailableException] : réseau absent, quota épuisé, service down.
///   L'appelant met la demande en attente et la reprendra plus tard.
/// - [LlmBadOutputException] : le fournisseur a répondu hors format même
///   après la relance interne. L'appelant signale l'échec sans rien casser.
library;

abstract interface class LlmProvider {
  /// Met au propre un texte dicté (langage parlé → écrit), sans en changer
  /// le sens ni la langue. Renvoie uniquement le texte reformulé.
  Future<String> reformulate(String rawText);

  /// Condense un texte dicté en une synthèse courte et fidèle.
  Future<String> summarize(String rawText);
}

/// Le fournisseur est momentanément inutilisable (réseau, quota, 5xx).
class LlmUnavailableException implements Exception {
  const LlmUnavailableException(this.reason);
  final String reason;

  @override
  String toString() => 'LlmUnavailableException: $reason';
}

/// Le fournisseur a répondu, mais la sortie est inexploitable.
class LlmBadOutputException implements Exception {
  const LlmBadOutputException(this.reason);
  final String reason;

  @override
  String toString() => 'LlmBadOutputException: $reason';
}
