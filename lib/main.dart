import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/data/database.dart';
import 'src/data/folder_repository.dart';
import 'src/data/key_store.dart';
import 'src/data/note_repository.dart';
import 'src/domain/dictation/fake_dictation_engine.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final key = await FileKeyStore().obtainDatabaseKey();
  final db = AppDatabase(openEncryptedDatabase(key: key));

  // Moteur simulé partout pour l'instant. Le moteur iOS (framework Speech)
  // sera branché ici, selon la plateforme, à la livraison iPhone.
  runApp(MentionApp(
    dictationEngine: FakeDictationEngine(),
    noteRepository: NoteRepository(db),
    folderRepository: FolderRepository(db),
  ));
}
