import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../domain/folder.dart';
import 'database.dart';

/// Accès aux dossiers de l'arborescence.
class FolderRepository {
  FolderRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  /// Sous-dossiers directs de [parentId] (nul = racine),
  /// triés par position puis par nom.
  Stream<List<Folder>> watchChildren(String? parentId) {
    final query = _db.select(_db.folders)
      ..where((t) =>
          parentId == null ? t.parentId.isNull() : t.parentId.equals(parentId))
      ..orderBy([
        (t) => OrderingTerm.asc(t.position),
        (t) => OrderingTerm.asc(t.name),
      ]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  /// Tous les dossiers, pour le sélecteur de déplacement.
  Future<List<Folder>> getAll() async {
    final rows = await (_db.select(_db.folders)
          ..orderBy([
            (t) => OrderingTerm.asc(t.position),
            (t) => OrderingTerm.asc(t.name),
          ]))
        .get();
    return rows.map(_toDomain).toList();
  }

  Future<Folder?> getById(String id) async {
    final row = await (_db.select(_db.folders)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  /// Crée un dossier. Ignore un nom vide.
  Future<Folder?> create(String name, {String? parentId}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    final folder = Folder(id: _uuid.v4(), name: trimmed, parentId: parentId);
    await _db.into(_db.folders).insert(FoldersCompanion.insert(
          id: folder.id,
          name: folder.name,
          parentId: Value(parentId),
        ));
    return folder;
  }

  Future<void> rename(String id, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    await (_db.update(_db.folders)..where((t) => t.id.equals(id)))
        .write(FoldersCompanion(name: Value(trimmed)));
  }

  /// Contenu total d'un dossier (sous-arbre entier), pour que la
  /// confirmation de suppression annonce ce qui sera détruit.
  Future<({int notes, int folders})> countContent(String id) async {
    final ids = await _subtreeIds(id);
    final countExp = _db.notes.id.count();
    final row = await (_db.selectOnly(_db.notes)
          ..addColumns([countExp])
          ..where(_db.notes.folderId.isIn(ids)))
        .getSingle();
    return (notes: row.read(countExp) ?? 0, folders: ids.length - 1);
  }

  /// Supprime un dossier **et tout son contenu** (sous-dossiers et notes).
  /// Choix utilisateur du 2026-09-09 : suppression destructive, précédée
  /// d'une confirmation qui annonce le contenu — pas de remontée au parent.
  Future<void> delete(String id) async {
    final ids = await _subtreeIds(id);
    await _db.transaction(() async {
      await (_db.delete(_db.notes)..where((t) => t.folderId.isIn(ids))).go();
      await (_db.delete(_db.folders)..where((t) => t.id.isIn(ids))).go();
    });
  }

  /// Identifiants du sous-arbre de [id], dossier lui-même compris.
  Future<List<String>> _subtreeIds(String id) async {
    final all = await _db.select(_db.folders).get();
    final childrenOf = <String?, List<String>>{};
    for (final f in all) {
      childrenOf.putIfAbsent(f.parentId, () => []).add(f.id);
    }
    final result = <String>[];
    final queue = [id];
    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      result.add(current);
      queue.addAll(childrenOf[current] ?? const []);
    }
    return result;
  }

  Folder _toDomain(FolderRow row) => Folder(
        id: row.id,
        name: row.name,
        parentId: row.parentId,
        position: row.position,
      );
}
