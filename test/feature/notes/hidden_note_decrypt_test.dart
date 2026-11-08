import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kawai_notes/core/services/encryption_service.dart';
import 'package:kawai_notes/core/services/note_file_service.dart';
import 'package:kawai_notes/di/repository_providers.dart';
import 'package:kawai_notes/feature/notes/providers/hidden_note_list_provider.dart';
import 'package:kawai_notes/feature/notes/providers/note_providers.dart';
import 'package:kawai_notes/feature/notes/repositories/note_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/objectbox_test_store.dart';

class MockNoteFileService extends Mock implements NoteFileService {}

class MockEncryptionService extends Mock implements EncryptionService {}

const _keyName = 'kawai_notes_encryption_key';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EncryptionService (real AES-GCM, in-memory secure storage)', () {
    late Map<String, String> secure;

    setUp(() {
      secure = <String, String>{};
      FlutterSecureStorage.setMockInitialValues(secure);
    });

    test('decrypt with a missing key throws and never creates a key', () async {
      final ciphertext = await EncryptionService().encrypt('secret');
      secure.clear();

      await expectLater(
        EncryptionService().decrypt(ciphertext),
        throwsA(isA<DecryptionException>()),
      );
      expect(secure.containsKey(_keyName), isFalse);
    });

    test('decrypt of corrupt ciphertext throws a typed error', () async {
      await EncryptionService().encrypt('seed key');

      await expectLater(
        EncryptionService().decrypt('bm90LXJlYWwtY2lwaGVydGV4dC1hdC1hbGwh'),
        throwsA(isA<DecryptionException>()),
      );
    });

    test('concurrent first use creates exactly one key', () async {
      final service = EncryptionService();
      final results = await Future.wait([
        service.encrypt('a'),
        service.encrypt('b'),
      ]);

      expect(await EncryptionService().decrypt(results[0]), 'a');
      expect(await EncryptionService().decrypt(results[1]), 'b');
    });
  });

  group('callers preserve ciphertext when decrypt fails', () {
    late ObjectBoxTestStore testStore;
    late MockEncryptionService enc;
    late NoteRepository repository;
    late ProviderContainer container;

    setUp(() async {
      testStore = await ObjectBoxTestStore.open();
      enc = MockEncryptionService();
      when(() => enc.encrypt(any())).thenAnswer(
        (i) async => 'enc:${i.positionalArguments[0]}',
      );
      repository = NoteRepository(
        testStore.service,
        MockNoteFileService(),
        enc,
        isHiddenUnlocked: () => true,
      );
      container = ProviderContainer(
        overrides: [noteRepositoryProvider.overrideWithValue(repository)],
      );
    });

    tearDown(() {
      container.dispose();
      testStore.close();
    });

    Future<int> hiddenNoteWithBrokenKey() async {
      final n = await repository.saveNote(
        title: 'S',
        content: 'secret',
        isHidden: true,
      );
      when(() => enc.decrypt(any())).thenThrow(Exception('key mismatch'));
      return n.id;
    }

    test('getNoteContent throws DecryptionException instead of a string', () async {
      final id = await hiddenNoteWithBrokenKey();

      await expectLater(
        repository.getNoteContent(repository.getNote(id)!),
        throwsA(isA<DecryptionException>()),
      );
    });

    test('unhide keeps the note hidden and its ciphertext intact', () async {
      final id = await hiddenNoteWithBrokenKey();
      await container.read(hiddenNoteListNotifierProvider.future);

      await container
          .read(hiddenNoteListNotifierProvider.notifier)
          .unhideNotes([id]);

      final after = repository.getNote(id)!;
      expect(after.isHidden, isTrue);
      expect(after.content, 'enc:secret');
    });

    test('editor marks decryptFailed and a title edit keeps ciphertext', () async {
      final id = await hiddenNoteWithBrokenKey();
      final sub = container.listen(noteDetailNotifierProvider(id), (_, _) {});
      addTearDown(sub.close);

      final state = await container.read(noteDetailNotifierProvider(id).future);
      expect(state.decryptFailed, isTrue);
      expect(state.content, isNot(contains('Error decrypting')));

      await container
          .read(noteDetailNotifierProvider(id).notifier)
          .saveNote(title: 'S2', content: state.content);

      final after = repository.getNote(id)!;
      expect(after.content, 'enc:secret');
      expect(after.title, 'S');
    });

    test('preview does not surface decrypt error text', () async {
      final id = await hiddenNoteWithBrokenKey();

      final preview = await container.read(notePreviewProvider(id).future);

      expect(preview, isNot(contains('Error decrypting')));
      expect(preview, isNot(contains('key mismatch')));
    });

    test('batch colour change on an undecryptable note keeps ciphertext', () async {
      final id = await hiddenNoteWithBrokenKey();
      await container.read(noteListNotifierProvider.future);

      await container
          .read(noteListNotifierProvider.notifier)
          .batchUpdateBackground([id], colorValue: 0xFF112233);

      final after = repository.getNote(id)!;
      expect(after.content, 'enc:secret');
      expect(after.colorValue, 0xFF112233);
    });
  });
}
