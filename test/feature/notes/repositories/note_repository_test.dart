import 'package:flutter_test/flutter_test.dart';
import 'package:kawai_notes/core/services/encryption_service.dart';
import 'package:kawai_notes/core/services/note_file_service.dart';
import 'package:kawai_notes/feature/notes/models/note.dart';
import 'package:kawai_notes/feature/notes/repositories/note_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/objectbox_test_store.dart';

class MockNoteFileService extends Mock implements NoteFileService {}

class MockEncryptionService extends Mock implements EncryptionService {}

void main() {
  late ObjectBoxTestStore testStore;
  late MockNoteFileService noteFileService;
  late MockEncryptionService encryptionService;
  late NoteRepository repository;

  setUp(() async {
    testStore = await ObjectBoxTestStore.open();
    noteFileService = MockNoteFileService();
    encryptionService = MockEncryptionService();
    repository = NoteRepository(
      testStore.service,
      noteFileService,
      encryptionService,
    );

    when(() => encryptionService.encrypt(any())).thenAnswer(
      (invocation) async => 'enc:${invocation.positionalArguments[0]}',
    );
    when(() => encryptionService.decrypt(any())).thenAnswer(
      (invocation) async =>
          (invocation.positionalArguments[0] as String).replaceFirst(
            'enc:',
            '',
          ),
    );
    when(() => noteFileService.deleteNoteFile(any())).thenAnswer((_) async {});
  });

  tearDown(() => testStore.close());

  test('saveNote persists a plaintext note untouched', () async {
    final note = await repository.saveNote(title: 'Hello', content: 'World');

    expect(note.id, isNot(0));
    expect(note.content, 'World');
    expect(note.isHidden, isFalse);
    verifyNever(() => encryptionService.encrypt(any()));
  });

  test('saveNote encrypts content for hidden notes', () async {
    final note = await repository.saveNote(
      title: 'Secret',
      content: 'Top secret',
      isHidden: true,
    );

    expect(note.content, 'enc:Top secret');
    verify(() => encryptionService.encrypt('Top secret')).called(1);
  });

  test('saveNote extracts tags and links from content', () async {
    final note = await repository.saveNote(
      title: 'Note',
      content: 'Has a #tag and a [[link]]',
    );

    expect(note.tags, contains('tag'));
    expect(note.links, contains('link'));
  });

  test('getNoteContent decrypts hidden note content', () async {
    final note = await repository.saveNote(
      title: 'Secret',
      content: 'Top secret',
      isHidden: true,
    );

    final content = await repository.getNoteContent(note);

    expect(content, 'Top secret');
    verify(() => encryptionService.decrypt('enc:Top secret')).called(1);
  });

  test('getAllNotes returns every saved note', () async {
    await repository.saveNote(title: 'A', content: '1');
    await repository.saveNote(title: 'B', content: '2');

    expect(repository.getAllNotes(), hasLength(2));
  });

  test('deleteNote soft-deletes by flipping isDeleted', () async {
    final note = await repository.saveNote(title: 'A', content: '1');

    await repository.deleteNote(note.id);

    expect(repository.getNote(note.id)?.isDeleted, isTrue);
  });

  test('restoreNote clears isDeleted', () async {
    final note = await repository.saveNote(title: 'A', content: '1');
    await repository.deleteNote(note.id);

    await repository.restoreNote(note.id);

    expect(repository.getNote(note.id)?.isDeleted, isFalse);
  });

  test('hardDeleteNote removes the note from the store', () async {
    final note = await repository.saveNote(title: 'A', content: '1');

    await repository.hardDeleteNote(note.id);

    expect(repository.getNote(note.id), isNull);
  });

  test('updateNotePin toggles the pinned flag', () async {
    final note = await repository.saveNote(title: 'A', content: '1');

    await repository.updateNotePin(note.id, true);

    expect(repository.getNote(note.id)?.isPinned, isTrue);
  });

  test('cleanUpTrashNotes hard-deletes trash older than the threshold', () async {
    final old = await repository.saveNote(title: 'Old', content: '1');
    final recent = await repository.saveNote(title: 'Recent', content: '2');
    await repository.deleteNote(old.id);
    await repository.deleteNote(recent.id);

    // deleteNote stamps updatedAt = now, so backdate the "old" trash entry
    // directly to simulate it having sat in trash past the threshold.
    final box = testStore.service.store.box<Note>();
    final oldInTrash = box.get(old.id)!
      ..updatedAt = DateTime.now().subtract(const Duration(days: 40));
    box.put(oldInTrash);

    await repository.cleanUpTrashNotes(days: 30);

    expect(repository.getNote(old.id), isNull);
    expect(repository.getNote(recent.id), isNotNull);
  });
}
