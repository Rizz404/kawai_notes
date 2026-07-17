import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kawai_notes/core/services/encryption_service.dart';
import 'package:kawai_notes/core/services/note_file_service.dart';
import 'package:kawai_notes/di/repository_providers.dart';
import 'package:kawai_notes/feature/notes/providers/note_detail_provider.dart';
import 'package:kawai_notes/feature/notes/repositories/note_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/objectbox_test_store.dart';

class MockNoteFileService extends Mock implements NoteFileService {}

class MockEncryptionService extends Mock implements EncryptionService {}

void main() {
  late ObjectBoxTestStore testStore;
  late ProviderContainer container;
  late NoteRepository repository;

  setUp(() async {
    testStore = await ObjectBoxTestStore.open();
    final encryptionService = MockEncryptionService();
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

    repository = NoteRepository(
      testStore.service,
      MockNoteFileService(),
      encryptionService,
    );
    container = ProviderContainer(
      overrides: [noteRepositoryProvider.overrideWithValue(repository)],
    );
  });

  tearDown(() {
    container.dispose();
    testStore.close();
  });

  test('build with a null id starts an empty (create) state', () async {
    final state = await container.read(
      noteDetailNotifierProvider(null).future,
    );

    expect(state.note, isNull);
    expect(state.content, isEmpty);
  });

  test('build with an existing id loads the note and its content', () async {
    final note = await repository.saveNote(title: 'Groceries', content: 'Milk, eggs');

    final state = await container.read(
      noteDetailNotifierProvider(note.id).future,
    );

    expect(state.note?.title, 'Groceries');
    expect(state.content, 'Milk, eggs');
  });

  test('saveNote on a null id creates a new note', () async {
    await container.read(noteDetailNotifierProvider(null).future);

    await container
        .read(noteDetailNotifierProvider(null).notifier)
        .saveNote(title: 'New note', content: 'Hello');

    expect(repository.getAllNotes().map((n) => n.title), contains('New note'));
  });

  test('saveNote on an existing id updates it in place, not a duplicate', () async {
    final note = await repository.saveNote(title: 'Groceries', content: 'Milk');
    await container.read(noteDetailNotifierProvider(note.id).future);

    await container
        .read(noteDetailNotifierProvider(note.id).notifier)
        .saveNote(title: 'Groceries', content: 'Milk, eggs, bread');

    expect(repository.getAllNotes(), hasLength(1));
    expect(repository.getNote(note.id)?.content, 'Milk, eggs, bread');
  });

  test('saveNote is a no-op when nothing actually changed', () async {
    final note = await repository.saveNote(title: 'Groceries', content: 'Milk');
    await container.read(noteDetailNotifierProvider(note.id).future);
    final unchangedUpdatedAt = repository.getNote(note.id)!.updatedAt;

    await container
        .read(noteDetailNotifierProvider(note.id).notifier)
        .saveNote(title: 'Groceries', content: 'Milk');

    expect(repository.getNote(note.id)?.updatedAt, unchangedUpdatedAt);
  });

  test('saveNote encrypts content when isHidden is set true', () async {
    final note = await repository.saveNote(title: 'Secret', content: 'plain');
    await container.read(noteDetailNotifierProvider(note.id).future);

    await container
        .read(noteDetailNotifierProvider(note.id).notifier)
        .saveNote(title: 'Secret', content: 'plain', isHidden: true);

    final saved = repository.getNote(note.id)!;
    expect(saved.isHidden, isTrue);
    expect(saved.content, 'enc:plain');
  });
}
