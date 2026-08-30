import 'dart:async';

import 'dictation_engine.dart';

/// Substitut du moteur de dictée pour le développement sans iPhone.
///
/// Émet une phrase prédéfinie mot par mot, comme le ferait la reconnaissance
/// vocale iOS avec ses résultats partiels cumulatifs.
class FakeDictationEngine implements DictationEngine {
  FakeDictationEngine({
    this.sentence =
        'Ceci est une dictée simulée pour développer sans appareil.',
    this.wordInterval = const Duration(milliseconds: 300),
  });

  final String sentence;
  final Duration wordInterval;

  DictationStatus _status = DictationStatus.idle;
  StreamController<DictationEvent>? _controller;
  Timer? _timer;

  @override
  DictationStatus get status => _status;

  @override
  Future<bool> initialize() async => true;

  @override
  Stream<DictationEvent> start() {
    final words = sentence.split(' ');
    var emitted = 0;
    final controller = StreamController<DictationEvent>();
    _controller = controller;
    _status = DictationStatus.listening;

    _timer = Timer.periodic(wordInterval, (timer) {
      emitted++;
      final partial = words.take(emitted).join(' ');
      final done = emitted >= words.length;
      controller.add(DictationEvent(transcript: partial, isFinal: done));
      if (done) {
        timer.cancel();
        _finish();
      }
    });

    return controller.stream;
  }

  @override
  Future<void> stop() async {
    if (_status != DictationStatus.listening) return;
    _timer?.cancel();
    _finish();
  }

  void _finish() {
    _status = DictationStatus.stopped;
    _controller?.close();
    _controller = null;
  }
}
