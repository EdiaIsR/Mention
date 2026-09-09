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

  /// Notes d'un dossier (nul = notes non classées, à la racine),
  /// la plus récente d'abord.
  Stream<List<Note>> watchByFolder(String? folderId) {
    final query = _db.select(_db.notes)
      ..where((t) =>
          folderId == null ? t.folderId.isNull() : t.folderId.equals(folderId))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  /// Recherche plein texte simple (LIKE, insensible à la casse ASCII).
  Future<List<Note>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];
    final escaped = trimmed
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    final rows = await (_db.select(_db.notes)
          ..where((t) => t.rawText.like('%$escaped%', escapeChar: r'\'))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
    return rows.map(_toDomain).toList();
  }

  /// Déplace une note ([folderId] nul = vers la racine).
  Future<void> moveToFolder(String noteId, String? folderId) async {
    await (_db.update(_db.notes)..where((t) => t.id.equals(noteId))).write(
      NotesCompanion(
        folderId: Value(folderId),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Édition manuelle du texte par l'utilisateur — seule opération autorisée
  /// à modifier rawText (les traitements LLM écriront ailleurs).
  Future<void> updateRawText(String noteId, String newText) async {
    if (newText.trim().isEmpty) return;
    await (_db.update(_db.notes)..where((t) => t.id.equals(noteId))).write(
      NotesCompanion(
        rawText: Value(newText),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> delete(String noteId) async {
    await (_db.delete(_db.notes)..where((t) => t.id.equals(noteId))).go();
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

  /// Crée une note brute dans [folderId] (nul = racine). Ignore
  /// silencieusement un texte vide : une dictée interrompue avant le
  /// premier mot ne crée rien.
  Future<Note?> create(String rawText, {String? folderId}) async {
    if (rawText.trim().isEmpty) return null;
    final now = DateTime.now();
    final note = Note(
      id: _uuid.v4(),
      rawText: rawText,
      folderId: folderId,
      createdAt: now,
      updatedAt: now,
    );
    await _db.into(_db.notes).insert(NotesCompanion.insert(
          id: note.id,
          rawText: note.rawText,
          folderId: Value(folderId),
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
