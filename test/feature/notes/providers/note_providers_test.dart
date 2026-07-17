import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kawai_notes/core/services/encryption_service.dart';
import 'package:kawai_notes/core/services/note_file_service.dart';
import 'package:kawai_notes/di/repository_providers.dart';
import 'package:kawai_notes/feature/notes/providers/note_providers.dart';
import 'package:kawai_notes/feature/notes/repositories/note_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/objectbox_test_store.dart';

class MockNoteFileService extends Mock implements NoteFileService {}

class MockEncryptionService extends Mock implements EncryptionService {}

void main() {
  group('IsGridViewNotifier', () {
    test('defaults to grid view and toggles', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(isGridViewProvider), isTrue);

      container.read(isGridViewProvider.notifier).toggle();
      expect(container.read(isGridViewProvider), isFalse);

      container.read(isGridViewProvider.notifier).toggle();
      expect(container.read(isGridViewProvider), isTrue);
    });
  });

  group('NotePreviewNotifier', () {
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

    test('strips markdown formatting down to plain text', () async {
      final note = await repository.saveNote(
        title: 'Note',
        content: '# Heading\n**bold** and *italic* and `code`',
      );

      final preview = await container.read(notePreviewProvider(note.id).future);

      expect(preview, 'Heading bold and italic and code');
    });

    test('returns an empty string for a missing note', () async {
      final preview = await container.read(notePreviewProvider(999).future);

      expect(preview, isEmpty);
    });
  });
}
