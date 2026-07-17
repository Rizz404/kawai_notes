import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kawai_notes/core/services/encryption_service.dart';
import 'package:kawai_notes/core/services/note_file_service.dart';
import 'package:kawai_notes/di/repository_providers.dart';
import 'package:kawai_notes/feature/notes/repositories/note_repository.dart';
import 'package:kawai_notes/feature/other/providers/trash_provider.dart';
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
    repository = NoteRepository(
      testStore.service,
      MockNoteFileService(),
      MockEncryptionService(),
    );
    container = ProviderContainer(
      overrides: [noteRepositoryProvider.overrideWithValue(repository)],
    );
  });

  tearDown(() {
    container.dispose();
    testStore.close();
  });

  test('build only lists deleted notes, newest updatedAt first', () async {
    await repository.saveNote(title: 'Kept', content: 'a');
    final older = await repository.saveNote(title: 'Older trash', content: 'b');
    final newer = await repository.saveNote(title: 'Newer trash', content: 'c');
    await repository.deleteNote(older.id);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await repository.deleteNote(newer.id);

    final items = await container.read(trashListNotifierProvider.future);

    expect(items.map((n) => n.title), ['Newer trash', 'Older trash']);
  });

  test('restoreNote clears isDeleted and drops it from trash', () async {
    final note = await repository.saveNote(title: 'A', content: '1');
    await repository.deleteNote(note.id);
    await container.read(trashListNotifierProvider.future);

    await container.read(trashListNotifierProvider.notifier).restoreNote(note.id);

    expect(repository.getNote(note.id)?.isDeleted, isFalse);
    final items = await container.read(trashListNotifierProvider.future);
    expect(items, isEmpty);
  });

  test('deletePermanently hard-deletes a single note', () async {
    final a = await repository.saveNote(title: 'A', content: '1');
    final b = await repository.saveNote(title: 'B', content: '2');
    await repository.deleteNote(a.id);
    await repository.deleteNote(b.id);
    await container.read(trashListNotifierProvider.future);

    await container
        .read(trashListNotifierProvider.notifier)
        .deletePermanently(a.id);

    expect(repository.getNote(a.id), isNull);
    expect(repository.getNote(b.id), isNotNull);
  });

  test('emptyTrash hard-deletes every note currently in trash', () async {
    final a = await repository.saveNote(title: 'A', content: '1');
    final b = await repository.saveNote(title: 'B', content: '2');
    final kept = await repository.saveNote(title: 'Kept', content: '3');
    await repository.deleteNote(a.id);
    await repository.deleteNote(b.id);
    await container.read(trashListNotifierProvider.future);

    await container.read(trashListNotifierProvider.notifier).emptyTrash();

    expect(repository.getNote(a.id), isNull);
    expect(repository.getNote(b.id), isNull);
    expect(repository.getNote(kept.id), isNotNull);
  });
}
