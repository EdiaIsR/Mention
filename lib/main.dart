import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/domain/dictation/fake_dictation_engine.dart';

void main() {
  // Lot 0 : moteur simulé partout. Le moteur iOS (framework Speech)
  // arrive au lot 1 et sera choisi ici selon la plateforme.
  runApp(MentionApp(dictationEngine: FakeDictationEngine()));
}
