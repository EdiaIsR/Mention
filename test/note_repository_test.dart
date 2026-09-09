import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mention/src/data/database.dart';
import 'package:mention/src/data/note_repository.dart';

void main() {
  late AppDatabase db;
  late NoteRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = NoteRepository(db);
  });

  tearDown(() => db.close());

  test('créer puis retrouver une note', () async {
    final created = await repo.create('Acheter du pain\net du lait');
    expect(created, isNotNull);

    final fetched = await repo.getById(created!.id);
    expect(fetched!.rawText, 'Acheter du pain\net du lait');
    expect(fetched.excerpt, 'Acheter du pain');
    expect(fetched.folderId, isNull);
  });

  test('watchAll émet les notes, la plus récente d\'abord', () async {
    await repo.create('première');
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    await repo.create('seconde');

    final notes = await repo.watchAll().first;
    expect(notes.map((n) => n.rawText).toList(), ['seconde', 'première']);
  });

  test('un texte vide ou blanc ne crée rien', () async {
    expect(await repo.create(''), isNull);
    expect(await repo.create('   \n '), isNull);
    expect(await repo.watchAll().first, isEmpty);
  });
}
