import 'package:flutter/material.dart';

import 'domain/dictation/dictation_engine.dart';
import 'ui/home/home_page.dart';

class MentionApp extends StatelessWidget {
  const MentionApp({super.key, required this.dictationEngine});

  final DictationEngine dictationEngine;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mention',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: HomePage(engine: dictationEngine),
    );
  }
}
