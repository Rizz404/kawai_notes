import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kawai_notes/core/services/encryption_service.dart';
import 'package:kawai_notes/core/services/note_file_service.dart';
import 'package:kawai_notes/di/repository_providers.dart';
import 'package:kawai_notes/feature/notes/providers/hidden_note_list_provider.dart';
import 'package:kawai_notes/feature/notes/providers/note_list_provider.dart';
import 'package:kawai_notes/feature/notes/repositories/note_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/objectbox_test_store.dart';

class MockNoteFileService extends Mock implements NoteFileService {}

class MockEncryptionService extends Mock implements EncryptionService {}

/// P4: a mutation must not silently drop the active search filter.
void main() {
  late ObjectBoxTestStore testStore;
  late NoteRepository notes;
  late ProviderContainer container;

  setUp(() async {
    testStore = await ObjectBoxTestStore.open();
    final enc = MockEncryptionService();
    when(() => enc.encrypt(any())).thenAnswer((i) async => 'enc:${i.positionalArguments[0]}');
    when(() => enc.decrypt(any())).thenAnswer(
      (i) async => (i.positionalArguments[0] as String).replaceFirst('enc:', ''),
    );
    notes = NoteRepository(
      testStore.service,
      MockNoteFileService(),
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

  test('pinning keeps the home search filter', () async {
    final a = await notes.saveNote(title: 'apple pie', content: '');
    await notes.saveNote(title: 'banana', content: '');
    final sub = container.listen(noteListNotifierProvider, (_, _) {});
    await container.read(noteListNotifierProvider.future);
    final n = container.read(noteListNotifierProvider.notifier);
    await n.search('apple');
    await n.pinNotes([a.id], isPinned: true);
    final s = await container.read(noteListNotifierProvider.future);
    sub.close();
    expect(s.query, 'apple');
    expect(s.items.map((e) => e.title), ['apple pie']);
  });

  test('deleting keeps the home search filter', () async {
    final a = await notes.saveNote(title: 'apple pie', content: '');
    await notes.saveNote(title: 'apple tart', content: '');
    await notes.saveNote(title: 'banana', content: '');
    final sub = container.listen(noteListNotifierProvider, (_, _) {});
    await container.read(noteListNotifierProvider.future);
    final n = container.read(noteListNotifierProvider.notifier);
    await n.search('apple');
    await n.deleteNote(a.id);
    final s = await container.read(noteListNotifierProvider.future);
    sub.close();
    expect(s.query, 'apple');
    expect(s.items.map((e) => e.title), ['apple tart']);
  });

  test('hidden list unhide keeps the hidden search filter', () async {
    final a = await notes.saveNote(title: 'diary one', content: 'x', isHidden: true);
    await notes.saveNote(title: 'diary two', content: 'y', isHidden: true);
    await notes.saveNote(title: 'other', content: 'z', isHidden: true);
    final sub = container.listen(hiddenNoteListNotifierProvider, (_, _) {});
    await container.read(hiddenNoteListNotifierProvider.future);
    final n = container.read(hiddenNoteListNotifierProvider.notifier);
    await n.search('diary');
    await n.unhideNotes([a.id]);
    final s = await container.read(hiddenNoteListNotifierProvider.future);
    sub.close();
    expect(s.query, 'diary');
    expect(s.items.map((e) => e.title), ['diary two']);
  });
}
