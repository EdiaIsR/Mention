import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Fournit la clé de chiffrement de la base locale.
abstract interface class KeyStore {
  /// Renvoie la clé existante, ou en crée une au premier lancement.
  Future<String> obtainDatabaseKey();
}

/// Implémentation de développement (PC/Linux) : clé aléatoire persistée dans
/// un fichier du répertoire de données de l'app, en dehors du dépôt.
///
/// Sur iPhone, la clé ira dans le Keychain iOS (implémentation dédiée à la
/// livraison iOS) : un fichier ne survivrait pas correctement aux
/// sauvegardes/restaurations et n'offre pas la protection matérielle.
class FileKeyStore implements KeyStore {
  FileKeyStore({this.fileName = 'db.key'});

  final String fileName;

  @override
  Future<String> obtainDatabaseKey() async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, fileName));
    if (file.existsSync()) {
      final existing = file.readAsStringSync().trim();
      if (existing.isNotEmpty) return existing;
    }
    final rng = Random.secure();
    final key =
        List.generate(32, (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0'))
            .join();
    file.createSync(recursive: true);
    file.writeAsStringSync(key);
    return key;
  }
}
