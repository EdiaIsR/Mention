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

  /// Supprime un dossier. Son contenu (sous-dossiers et notes) n'est jamais
  /// détruit : il remonte dans le dossier parent.
  Future<void> delete(String id) async {
    final folder = await getById(id);
    if (folder == null) return;
    await _db.transaction(() async {
      final newParent = Value(folder.parentId);
      await (_db.update(_db.folders)..where((t) => t.parentId.equals(id)))
          .write(FoldersCompanion(parentId: newParent));
      await (_db.update(_db.notes)..where((t) => t.folderId.equals(id)))
          .write(NotesCompanion(folderId: newParent));
      await (_db.delete(_db.folders)..where((t) => t.id.equals(id))).go();
    });
  }

  Folder _toDomain(FolderRow row) => Folder(
        id: row.id,
        name: row.name,
        parentId: row.parentId,
        position: row.position,
      );
}
