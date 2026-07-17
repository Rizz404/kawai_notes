import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kawai_notes/core/services/encryption_service.dart';
import 'package:kawai_notes/core/services/note_file_service.dart';
import 'package:kawai_notes/di/repository_providers.dart';
import 'package:kawai_notes/feature/notes/providers/hidden_note_list_provider.dart';
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

  test('build only returns hidden, non-deleted notes', () async {
    await repository.saveNote(title: 'Visible', content: 'a');
    await repository.saveNote(title: 'Secret', content: 'b', isHidden: true);
    final deletedHidden = await repository.saveNote(
      title: 'Gone',
      content: 'c',
      isHidden: true,
    );
    await repository.deleteNote(deletedHidden.id);

    final state = await container.read(hiddenNoteListNotifierProvider.future);

    expect(state.items.map((n) => n.title), ['Secret']);
  });

  test('search matches decrypted content, not just title/tags', () async {
    await repository.saveNote(title: 'Recipe', content: 'contains carrot', isHidden: true);
    await repository.saveNote(title: 'Diary', content: 'nothing relevant', isHidden: true);
    await container.read(hiddenNoteListNotifierProvider.future);

    await container.read(hiddenNoteListNotifierProvider.notifier).search('carrot');

    final state = container.read(hiddenNoteListNotifierProvider).value!;
    expect(state.items.map((n) => n.title), ['Recipe']);
  });

  test('unhideNotes clears isHidden and drops the note from this list', () async {
    final note = await repository.saveNote(title: 'Secret', content: 'b', isHidden: true);
    await container.read(hiddenNoteListNotifierProvider.future);

    await container
        .read(hiddenNoteListNotifierProvider.notifier)
        .unhideNotes([note.id]);
    final state = await container.read(hiddenNoteListNotifierProvider.future);

    expect(repository.getNote(note.id)?.isHidden, isFalse);
    expect(state.items, isEmpty);
  });

  test('deleteNotes soft-deletes and refreshes the list', () async {
    final note = await repository.saveNote(title: 'Secret', content: 'b', isHidden: true);
    await container.read(hiddenNoteListNotifierProvider.future);

    await container
        .read(hiddenNoteListNotifierProvider.notifier)
        .deleteNotes([note.id]);

    expect(repository.getNote(note.id)?.isDeleted, isTrue);
    final state = await container.read(hiddenNoteListNotifierProvider.future);
    expect(state.items, isEmpty);
  });
}
