/// Abstraction du moteur de reconnaissance vocale.
///
/// L'implémentation réelle (framework Speech d'iOS) n'existe que sur iPhone.
/// Sur Linux desktop, un substitut [FakeDictationEngine] permet de faire
/// tourner l'app et de tester la logique sans appareil.
library;

/// État d'une session de dictée.
enum DictationStatus { idle, listening, stopped, unavailable }

/// Événement émis pendant une dictée : le texte transcrit jusqu'ici.
///
/// [isFinal] vaut true quand le moteur considère le segment comme définitif
/// (fin de session ou pause longue). Le texte est toujours cumulatif.
class DictationEvent {
  const DictationEvent({required this.transcript, required this.isFinal});

  final String transcript;
  final bool isFinal;
}

abstract interface class DictationEngine {
  /// Prépare le moteur (permissions, disponibilité). Renvoie false si la
  /// dictée est impossible sur cet appareil.
  Future<bool> initialize();

  /// Démarre l'écoute et émet la transcription au fil de l'eau.
  /// Le flux se ferme quand la session se termine (stop, interruption,
  /// limite de durée du moteur).
  Stream<DictationEvent> start();

  /// Arrête l'écoute. Le dernier événement émis porte isFinal = true.
  Future<void> stop();

  DictationStatus get status;
}
