import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kawai_notes/core/services/encryption_service.dart';
import 'package:kawai_notes/core/services/note_file_service.dart';
import 'package:kawai_notes/di/common_providers.dart';
import 'package:kawai_notes/di/repository_providers.dart';
import 'package:kawai_notes/feature/notes/models/note.dart';
import 'package:kawai_notes/feature/notes/providers/note_detail_provider.dart';
import 'package:kawai_notes/feature/notes/repositories/note_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/objectbox_test_store.dart';

class MockNoteFileService extends Mock implements NoteFileService {}

class MockEncryptionService extends Mock implements EncryptionService {}

/// Real repository whose save is held open until the test releases it, so
/// the editor can "pop" (drop its listener) while the save is in flight.
class _GatedNoteRepository extends NoteRepository {
  _GatedNoteRepository(super.objectBoxService, super.noteFileService, super.encryptionService);

  final started = Completer<void>();
  final gate = Completer<void>();
  Object? failWith;

  @override
  Future<Note> saveNote({
    int id = 0,
    String? ulid,
    required String title,
    required String content,
    int? folderId,
    bool isHidden = false,
    bool isPinned = false,
    int? colorValue,
    String? customBackgroundImage,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) async {
    started.complete();
    await gate.future;
    if (failWith case final error?) throw error;
    return super.saveNote(
      id: id,
      ulid: ulid,
      title: title,
      content: content,
      folderId: folderId,
      isHidden: isHidden,
      isPinned: isPinned,
      colorValue: colorValue,
      customBackgroundImage: customBackgroundImage,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

final class _DetailObserver extends ProviderObserver {
  final Object watched;
  final updates = <NoteDetailState>[];
  int disposals = 0;

  _DetailObserver(this.watched);

  @override
  void didUpdateProvider(
    ProviderObserverContext context,
    Object? previousValue,
    Object? newValue,
  ) {
    if (context.provider == watched && newValue is AsyncData<NoteDetailState>) {
      updates.add(newValue.value);
    }
  }

  @override
  void didDisposeProvider(ProviderObserverContext context) {
    if (context.provider == watched) disposals++;
  }
}

/// The create editor (`noteDetailNotifierProvider(null)`, autoDispose, not
/// cached) pops before its save completes. The save must still land, publish
/// its result and only then let the provider dispose.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ObjectBoxTestStore testStore;
  late _GatedNoteRepository repository;
  late _DetailObserver observer;
  late ProviderContainer container;
  final provider = noteDetailNotifierProvider(null);

  setUp(() async {
    testStore = await ObjectBoxTestStore.open();
    repository = _GatedNoteRepository(
      testStore.service,
      MockNoteFileService(),
      MockEncryptionService(),
    );
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    observer = _DetailObserver(provider);
    container = ProviderContainer(
      overrides: [
        noteRepositoryProvider.overrideWithValue(repository),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      observers: [observer],
    );
  });

  tearDown(() {
    container.dispose();
    testStore.close();
  });

  /// Opens the create editor, starts a save and removes the editor listener
  /// while the repository save is still pending.
  Future<({Future<void> save})> startSaveThenPop() async {
    final editor = container.listen(provider, (_, _) {});
    await container.read(provider.future);
    final save = container
        .read(provider.notifier)
        .saveNote(title: 'Draft', content: 'body');
    await repository.started.future;

    editor.close();
    await container.pump();
    return (save: save);
  }

  test('a pending save keeps the provider alive after the editor pops, '
      'then publishes the saved note and releases it', () async {
    final (:save) = await startSaveThenPop();
    final aliveWhilePending = container.exists(provider);
    final disposalsWhilePending = observer.disposals;

    repository.gate.complete();
    await save;
    await container.pump();

    expect(aliveWhilePending, isTrue);
    expect(disposalsWhilePending, 0);
    expect(repository.getAllNotes().map((n) => n.title), ['Draft']);
    final last = observer.updates.last;
    expect(last.isMutating, isFalse);
    expect(last.mutationError, isNull);
    expect(last.note?.id, isNot(0));
    expect(last.note?.title, 'Draft');
    // keep-alive link released: nothing listens any more, so it disposes
    expect(container.exists(provider), isFalse);
    expect(observer.disposals, 1);
  });

  test('a failing pending save still reports the error, then releases the '
      'provider', () async {
    final failure = StateError('disk full');
    repository.failWith = failure;
    final (:save) = await startSaveThenPop();
    final aliveWhilePending = container.exists(provider);

    repository.gate.complete();
    await save;
    await container.pump();

    expect(aliveWhilePending, isTrue);
    expect(repository.getAllNotes(), isEmpty);
    final last = observer.updates.last;
    expect(last.isMutating, isFalse);
    expect(last.mutationError, same(failure));
    expect(last.note, isNull);
    expect(container.exists(provider), isFalse);
    expect(observer.disposals, 1);
  });
}
