import 'package:flutter_test/flutter_test.dart';
import 'package:mention/src/domain/dictation/dictation_engine.dart';
import 'package:mention/src/domain/dictation/fake_dictation_engine.dart';

void main() {
  group('FakeDictationEngine', () {
    test('émet une transcription cumulative qui finit par isFinal', () async {
      final engine = FakeDictationEngine(
        sentence: 'un deux trois',
        wordInterval: const Duration(milliseconds: 1),
      );
      expect(await engine.initialize(), isTrue);

      final events = await engine.start().toList();

      expect(events.map((e) => e.transcript).toList(), [
        'un',
        'un deux',
        'un deux trois',
      ]);
      expect(events.last.isFinal, isTrue);
      expect(events.take(2).any((e) => e.isFinal), isFalse);
      expect(engine.status, DictationStatus.stopped);
    });

    test('stop interrompt la session et ferme le flux', () async {
      final engine = FakeDictationEngine(
        sentence: 'une phrase assez longue pour être interrompue',
        wordInterval: const Duration(milliseconds: 20),
      );
      await engine.initialize();

      final received = <DictationEvent>[];
      final done = engine.start().listen(received.add).asFuture<void>();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await engine.stop();
      await done;

      // Le texte déjà transcrit avant l'interruption n'est pas perdu.
      expect(received, isNotEmpty);
      expect(received.length, lessThan(7));
      expect(engine.status, DictationStatus.stopped);
    });
  });
}
