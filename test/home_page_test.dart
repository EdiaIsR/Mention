import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mention/src/app.dart';
import 'package:mention/src/domain/dictation/fake_dictation_engine.dart';

void main() {
  testWidgets('la dictée simulée s\'affiche en temps réel', (tester) async {
    final engine = FakeDictationEngine(
      sentence: 'bonjour le monde',
      wordInterval: const Duration(milliseconds: 100),
    );
    await tester.pumpWidget(MentionApp(dictationEngine: engine));

    expect(find.text('Appuie sur le micro pour dicter.'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('bonjour'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('bonjour le monde'), findsOneWidget);
  });
}
