import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kawai_notes/core/services/encryption_service.dart';
import 'package:kawai_notes/core/services/note_file_service.dart';
import 'package:kawai_notes/di/repository_providers.dart';
import 'package:kawai_notes/feature/notes/providers/note_list_provider.dart';
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
    final noteFileService = MockNoteFileService();
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
      noteFileService,
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

  test('build excludes hidden and deleted notes, pinned first', () async {
    await repository.saveNote(title: 'Normal', content: 'a');
    await repository.saveNote(title: 'Hidden', content: 'b', isHidden: true);
    final toDelete = await repository.saveNote(title: 'ToDelete', content: 'c');
    await repository.deleteNote(toDelete.id);
    await repository.saveNote(title: 'Pinned', content: 'd', isPinned: true);
    container.invalidate(noteListNotifierProvider);

    final state = await container.read(noteListNotifierProvider.future);

    expect(state.items.map((n) => n.title), ['Pinned', 'Normal']);
  });

  test('search filters by title', () async {
    await repository.saveNote(title: 'Grocery list', content: 'milk');
    await repository.saveNote(title: 'Work notes', content: 'meeting');
    container.invalidate(noteListNotifierProvider);
    await container.read(noteListNotifierProvider.future);

    await container.read(noteListNotifierProvider.notifier).search('grocery');

    final state = container.read(noteListNotifierProvider).value!;
    expect(state.items.map((n) => n.title), ['Grocery list']);
    expect(state.query, 'grocery');
  });

  test('deleteNote soft-deletes and refreshes the list', () async {
    final note = await repository.saveNote(title: 'A', content: '1');
    container.invalidate(noteListNotifierProvider);
    await container.read(noteListNotifierProvider.future);

    await container.read(noteListNotifierProvider.notifier).deleteNote(note.id);
    final state = await container.read(noteListNotifierProvider.future);

    expect(state.items, isEmpty);
    expect(repository.getNote(note.id)?.isDeleted, isTrue);
  });

  test('pinNotes updates pinned state and reorders the list', () async {
    final note = await repository.saveNote(title: 'A', content: '1');
    container.invalidate(noteListNotifierProvider);
    await container.read(noteListNotifierProvider.future);

    await container
        .read(noteListNotifierProvider.notifier)
        .pinNotes([note.id], isPinned: true);
    final state = await container.read(noteListNotifierProvider.future);

    expect(state.items.single.isPinned, isTrue);
  });
}
