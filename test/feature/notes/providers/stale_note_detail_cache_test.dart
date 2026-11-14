import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kawai_notes/core/services/encryption_service.dart';
import 'package:kawai_notes/core/services/note_file_service.dart';
import 'package:kawai_notes/di/common_providers.dart';
import 'package:kawai_notes/di/repository_providers.dart';
import 'package:kawai_notes/feature/notes/providers/hidden_note_list_provider.dart';
import 'package:kawai_notes/feature/notes/providers/note_providers.dart';
import 'package:kawai_notes/feature/notes/repositories/note_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/objectbox_test_store.dart';

class MockNoteFileService extends Mock implements NoteFileService {}

class MockEncryptionService extends Mock implements EncryptionService {}

/// The note detail state is cached for 5 minutes. List actions (hide,
/// unhide, pin, colour) change the stored note behind that cache; a later
/// editor save must never take the hidden flag (or pin/colour) from the
/// stale snapshot, and above all must never write a hidden note back out
/// of the vault in plaintext.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ObjectBoxTestStore testStore;
  late NoteRepository repo;
  late ProviderContainer container;

  setUp(() async {
    testStore = await ObjectBoxTestStore.open();
    final enc = MockEncryptionService();
    when(
      () => enc.encrypt(any()),
    ).thenAnswer((i) async => 'enc:${i.positionalArguments[0]}');
    when(() => enc.decrypt(any())).thenAnswer(
      (i) async => (i.positionalArguments[0] as String).replaceFirst('enc:', ''),
    );
    repo = NoteRepository(
      testStore.service,
      MockNoteFileService(),
      enc,
      isHiddenUnlocked: () => true,
    );
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        noteRepositoryProvider.overrideWithValue(repo),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    testStore.close();
  });

  /// Opens the editor for [id] (populating the 5-minute cache) and leaves.
  Future<void> openAndLeave(int id) async {
    final sub = container.listen(noteDetailNotifierProvider(id), (_, _) {});
    await container.read(noteDetailNotifierProvider(id).future);
    sub.close();
    await container.pump();
    expect(
      container.exists(noteDetailNotifierProvider(id)),
      isTrue,
      reason: 'precondition: the detail state is cached',
    );
  }

  /// Re-opens the editor and saves an edit the way NoteEditorScreen does
  /// for an existing note (isHidden: null, pin/colour from the state).
  Future<void> editAndSave(int id, String content) async {
    final p = noteDetailNotifierProvider(id);
    final sub = container.listen(p, (_, _) {});
    final state = await container.read(p.future);
    await container
        .read(p.notifier)
        .saveNote(
          title: state.note!.title,
          content: content,
          isPinned: state.note!.isPinned,
          colorValue: state.note!.colorValue,
        );
    sub.close();
  }

  test('hiding from the list then editing keeps the note hidden and '
      'encrypted', () async {
    final n = await repo.saveNote(title: 'A', content: 'plain');
    await openAndLeave(n.id);

    await container.read(noteListNotifierProvider.future);
    await container.read(noteListNotifierProvider.notifier).hideNotes([n.id]);
    expect(repo.getNote(n.id)!.isHidden, isTrue);

    await editAndSave(n.id, 'edited secret');

    final stored = repo.getNote(n.id)!;
    expect(stored.isHidden, isTrue);
    expect(stored.content, 'enc:edited secret');
  });

  test('unhiding in the vault then editing keeps the note visible', () async {
    final n = await repo.saveNote(title: 'B', content: 's', isHidden: true);
    await openAndLeave(n.id);

    await container.read(hiddenNoteListNotifierProvider.future);
    await container
        .read(hiddenNoteListNotifierProvider.notifier)
        .unhideNotes([n.id]);
    expect(repo.getNote(n.id)!.isHidden, isFalse);

    await editAndSave(n.id, 'now public');

    final stored = repo.getNote(n.id)!;
    expect(stored.isHidden, isFalse);
    expect(stored.content, 'now public');
  });

  test('pinning from the list is not undone by a later edit', () async {
    final n = await repo.saveNote(title: 'C', content: 'c');
    await openAndLeave(n.id);

    await container.read(noteListNotifierProvider.future);
    await container
        .read(noteListNotifierProvider.notifier)
        .pinNotes([n.id], isPinned: true);

    await editAndSave(n.id, 'c2');

    expect(repo.getNote(n.id)!.isPinned, isTrue);
  });

  test('a batch colour change is not undone by a later edit', () async {
    final n = await repo.saveNote(title: 'D', content: 'd');
    await openAndLeave(n.id);

    await container.read(noteListNotifierProvider.future);
    await container
        .read(noteListNotifierProvider.notifier)
        .batchUpdateBackground([n.id], colorValue: 0xFF00FF00);

    await editAndSave(n.id, 'd2');

    expect(repo.getNote(n.id)!.colorValue, 0xFF00FF00);
  });

  test('hiding refreshes the cached detail state', () async {
    final n = await repo.saveNote(title: 'E', content: 'visible text');
    await openAndLeave(n.id);

    await container.read(noteListNotifierProvider.future);
    await container.read(noteListNotifierProvider.notifier).hideNotes([n.id]);

    final state = await container.read(
      noteDetailNotifierProvider(n.id).future,
    );
    expect(state.note!.isHidden, isTrue);
    expect(state.content, 'visible text');
  });

  test('a stale snapshot hidden elsewhere never saves plaintext', () async {
    // * hidden behind the providers' back (e.g. another code path)
    final n = await repo.saveNote(title: 'F', content: 'plain');
    await openAndLeave(n.id);
    await repo.setNoteHidden(n.id, isHidden: true);

    await editAndSave(n.id, 'still secret');

    final stored = repo.getNote(n.id)!;
    expect(stored.isHidden, isTrue);
    expect(stored.content, 'enc:still secret');
  });

  test('control: an explicit hidden create still encrypts', () async {
    final p = noteDetailNotifierProvider(null);
    final sub = container.listen(p, (_, _) {});
    await container.read(p.future);
    await container
        .read(p.notifier)
        .saveNote(title: 'G', content: 'new secret', isHidden: true);
    sub.close();

    final stored = repo.getAllNotes().single;
    expect(stored.isHidden, isTrue);
    expect(stored.content, 'enc:new secret');
  });
}
