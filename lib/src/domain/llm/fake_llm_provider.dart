import 'llm_provider.dart';

/// Fournisseur simulé pour le développement PC et les tests.
///
/// Produit des transformations reconnaissables à l'œil (préfixe explicite)
/// et peut simuler l'indisponibilité pour tester la file d'attente.
class FakeLlmProvider implements LlmProvider {
  FakeLlmProvider({this.available = true, this.delay = Duration.zero});

  /// Passe à false pour simuler réseau coupé / quota épuisé.
  bool available;
  final Duration delay;

  @override
  Future<String> reformulate(String rawText) async {
    // Pas de Future.delayed(zéro) : sous l'horloge simulée des tests,
    // ce timer ne se déclencherait jamais sans pompage explicite.
    if (delay != Duration.zero) await Future<void>.delayed(delay);
    if (!available) {
      throw const LlmUnavailableException('fournisseur simulé indisponible');
    }
    return '[Reformulé — simulation]\n${rawText.trim()}';
  }

  @override
  Future<String> summarize(String rawText) async {
    if (delay != Duration.zero) await Future<void>.delayed(delay);
    if (!available) {
      throw const LlmUnavailableException('fournisseur simulé indisponible');
    }
    final words = rawText.trim().split(RegExp(r'\s+'));
    final head = words.take(12).join(' ');
    return '[Synthèse — simulation] $head…';
  }
}
