import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kawai_notes/core/services/encryption_service.dart';
import 'package:kawai_notes/core/services/note_file_service.dart';
import 'package:kawai_notes/di/repository_providers.dart';
import 'package:kawai_notes/feature/notes/models/note.dart';
import 'package:kawai_notes/feature/notes/providers/hidden_note_list_provider.dart';
import 'package:kawai_notes/feature/notes/providers/note_providers.dart';
import 'package:kawai_notes/feature/notes/repositories/note_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/objectbox_test_store.dart';

class MockNoteFileService extends Mock implements NoteFileService {}

class MockEncryptionService extends Mock implements EncryptionService {}

/// Inverted audit harness F3a/F3b/F3c/NEW-2: these assert the CORRECT
/// behaviour (fields preserved, trash not resurrected).
void main() {
  late ObjectBoxTestStore testStore;
  late MockEncryptionService enc;
  late MockNoteFileService files;
  late NoteRepository notes;
  late ProviderContainer container;
  final created = DateTime(2020, 1, 1);

  setUp(() async {
    testStore = await ObjectBoxTestStore.open();
    enc = MockEncryptionService();
    files = MockNoteFileService();
    when(() => enc.encrypt(any())).thenAnswer(
      (i) async => 'enc:${i.positionalArguments[0]}',
    );
    when(() => enc.decrypt(any())).thenAnswer(
      (i) async => (i.positionalArguments[0] as String).replaceFirst('enc:', ''),
    );
    notes = NoteRepository(
      testStore.service,
      files,
      enc,
      isHiddenUnlocked: () => true,
    );
    container = ProviderContainer(
      overrides: [noteRepositoryProvider.overrideWithValue(notes)],
    );
  });

  tearDown(() {
    container.dispose();
    testStore.close();
  });

  test('F3a hideNotes keeps pin, colour and createdAt', () async {
    final n = await notes.saveNote(
      title: 'T',
      content: 'c',
      isPinned: true,
      colorValue: 0xFF00FF00,
      createdAt: created,
      updatedAt: created,
    );
    await container.read(noteListNotifierProvider.future);

    await container.read(noteListNotifierProvider.notifier).hideNotes([n.id]);

    final after = notes.getNote(n.id)!;
    expect(after.isHidden, isTrue);
    expect(after.content, 'enc:c');
    expect(after.isPinned, isTrue);
    expect(after.colorValue, 0xFF00FF00);
    expect(after.createdAt, created);
  });

  test('F3b unhideNotes keeps pin, background and createdAt', () async {
    final n = await notes.saveNote(
      title: 'T',
      content: 'c',
      isHidden: true,
      isPinned: true,
      customBackgroundImage: '/docs/note_bg_1.png',
      createdAt: created,
      updatedAt: created,
    );
    await container.read(hiddenNoteListNotifierProvider.future);

    await container
        .read(hiddenNoteListNotifierProvider.notifier)
        .unhideNotes([n.id]);

    final after = notes.getNote(n.id)!;
    expect(after.isHidden, isFalse);
    expect(after.content, 'c');
    expect(after.isPinned, isTrue);
    expect(after.customBackgroundImage, '/docs/note_bg_1.png');
    expect(after.createdAt, created);
  });

  test('F3c saving a trashed note does not resurrect it', () async {
    final n = await notes.saveNote(title: 'T', content: 'c');
    await notes.deleteNote(n.id);

    await notes.saveNote(id: n.id, ulid: n.ulid, title: 'T', content: 'edit');

    final after = notes.getNote(n.id)!;
    expect(after.isDeleted, isTrue);
    expect(after.content, 'edit');
  });

  test('saveNote update without createdAt keeps the original', () async {
    final n = await notes.saveNote(
      title: 'T',
      content: 'c',
      createdAt: created,
      updatedAt: created,
    );

    await notes.saveNote(id: n.id, ulid: n.ulid, title: 'T', content: 'new');

    expect(notes.getNote(n.id)!.createdAt, created);
  });

  test('NEW-2 batchUpdateBackground keeps createdAt, pin and hidden', () async {
    final n = await notes.saveNote(
      title: 'T',
      content: 'c',
      isPinned: true,
      createdAt: created,
      updatedAt: created,
    );
    await container.read(noteListNotifierProvider.future);

    await container
        .read(noteListNotifierProvider.notifier)
        .batchUpdateBackground([n.id], colorValue: 0xFFFF0000);

    final after = notes.getNote(n.id)!;
    expect(after.colorValue, 0xFFFF0000);
    expect(after.isPinned, isTrue);
    expect(after.createdAt, created);
  });

  test('legacy migration of a hidden note keeps its ciphertext', () async {
    final n = await notes.saveNote(title: 'Old', content: 'x', isHidden: true);
    final stored = notes.getNote(n.id)!
      ..content = null;
    testStore.service.store.box<Note>().put(stored);
    when(() => files.readNoteFile(any())).thenAnswer((_) async => 'enc:legacy');

    await notes.migrateToSingleStorage();

    final after = notes.getNote(n.id)!;
    expect(after.isHidden, isTrue);
    expect(after.content, 'enc:legacy');
  });

  test('legacy migration survives an unreadable file', () async {
    final n = await notes.saveNote(title: 'Old', content: 'x');
    final stored = notes.getNote(n.id)!
      ..content = null;
    testStore.service.store.box<Note>().put(stored);
    when(() => files.readNoteFile(any())).thenThrow(Exception('io'));

    await notes.migrateToSingleStorage();

    expect(notes.getNote(n.id)!.content, isNull);
  });
}
