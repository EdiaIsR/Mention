import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../domain/note.dart';
import 'database.dart';

/// Accès aux notes. Seule couche autorisée à toucher la base ;
/// l'UI ne manipule que le modèle du domaine.
class NoteRepository {
  NoteRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  /// Toutes les notes, la plus récente d'abord. Flux réactif : la liste
  /// se met à jour à chaque écriture.
  Stream<List<Note>> watchAll() {
    final query = _db.select(_db.notes)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  /// Lecture ponctuelle, même ordre que [watchAll].
  Future<List<Note>> getAll() async {
    final query = _db.select(_db.notes)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    final rows = await query.get();
    return rows.map(_toDomain).toList();
  }

  Future<Note?> getById(String id) async {
    final row = await (_db.select(_db.notes)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  /// Crée une note brute. Ignore silencieusement un texte vide :
  /// une dictée interrompue avant le premier mot ne crée rien.
  Future<Note?> create(String rawText) async {
    if (rawText.trim().isEmpty) return null;
    final now = DateTime.now();
    final note = Note(
      id: _uuid.v4(),
      rawText: rawText,
      createdAt: now,
      updatedAt: now,
    );
    await _db.into(_db.notes).insert(NotesCompanion.insert(
          id: note.id,
          rawText: note.rawText,
          createdAt: note.createdAt,
          updatedAt: note.updatedAt,
        ));
    return note;
  }

  Note _toDomain(NoteRow row) => Note(
        id: row.id,
        rawText: row.rawText,
        folderId: row.folderId,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
      );
}
