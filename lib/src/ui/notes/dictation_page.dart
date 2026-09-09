import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/note_repository.dart';
import '../../domain/dictation/dictation_engine.dart';

/// Écran de dictée : l'écoute démarre à l'ouverture, la transcription
/// s'affiche au fil de l'eau, et la note est enregistrée dès que la session
/// se termine — bouton stop, fermeture de l'écran ou interruption du moteur.
/// Règle d'or : ce qui a été transcrit n'est jamais perdu.
class DictationPage extends StatefulWidget {
  const DictationPage({
    super.key,
    required this.repository,
    required this.engine,
    this.folderId,
  });

  final NoteRepository repository;
  final DictationEngine engine;

  /// Dossier de destination de la note (nul = racine).
  final String? folderId;

  @override
  State<DictationPage> createState() => _DictationPageState();
}

class _DictationPageState extends State<DictationPage> {
  String _transcript = '';
  bool _listening = false;
  bool _unavailable = false;
  bool _saved = false;
  StreamSubscription<DictationEvent>? _subscription;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final ready = await widget.engine.initialize();
    if (!mounted) return;
    if (!ready) {
      setState(() => _unavailable = true);
      return;
    }
    setState(() => _listening = true);
    _subscription = widget.engine.start().listen(
          (event) => setState(() => _transcript = event.transcript),
          onDone: _onSessionEnded,
          onError: (Object _) => _onSessionEnded(),
        );
  }

  /// Fin de session, quelle qu'en soit la cause : on persiste une seule fois.
  Future<void> _onSessionEnded() async {
    if (_saved) return;
    _saved = true;
    await widget.repository.create(_transcript, folderId: widget.folderId);
    if (mounted) {
      setState(() => _listening = false);
      Navigator.of(context).pop();
    }
  }

  Future<void> _stop() async {
    await widget.engine.stop();
    // La fermeture du flux déclenche _onSessionEnded via onDone.
  }

  @override
  void dispose() {
    _subscription?.cancel();
    // Écran fermé en pleine écoute (retour système) : sauvegarde de secours.
    if (!_saved && _transcript.trim().isNotEmpty) {
      _saved = true;
      widget.repository.create(_transcript, folderId: widget.folderId);
    }
    widget.engine.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dictée')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _unavailable
            ? const Center(
                child: Text('La dictée est indisponible sur cet appareil.'))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_listening)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text('Écoute en cours…',
                          style: TextStyle(fontStyle: FontStyle.italic)),
                    ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        _transcript.isEmpty ? '…' : _transcript,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ),
                ],
              ),
      ),
      floatingActionButton: _listening
          ? FloatingActionButton(
              tooltip: 'Arrêter et enregistrer',
              onPressed: _stop,
              child: const Icon(Icons.stop),
            )
          : null,
    );
  }
}
