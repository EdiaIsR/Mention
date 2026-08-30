import 'package:flutter/material.dart';

import '../../domain/dictation/dictation_engine.dart';

/// Écran d'accueil du lot 0 : vérifie que le câblage moteur de dictée → UI
/// fonctionne. Sera remplacé par le vrai écran de dictée au lot 1.
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.engine});

  final DictationEngine engine;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _transcript = '';
  bool _listening = false;

  Future<void> _toggle() async {
    if (_listening) {
      await widget.engine.stop();
      return;
    }
    final ready = await widget.engine.initialize();
    if (!ready || !mounted) return;
    setState(() {
      _listening = true;
      _transcript = '';
    });
    widget.engine.start().listen(
      (event) => setState(() => _transcript = event.transcript),
      onDone: () {
        if (mounted) setState(() => _listening = false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mention')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  _transcript.isEmpty
                      ? 'Appuie sur le micro pour dicter.'
                      : _transcript,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _toggle,
        child: Icon(_listening ? Icons.stop : Icons.mic),
      ),
    );
  }
}
