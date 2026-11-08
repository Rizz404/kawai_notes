import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kawai_notes/core/services/encryption_service.dart';
import 'package:kawai_notes/core/services/note_file_service.dart';
import 'package:kawai_notes/feature/notes/models/note.dart';
import 'package:kawai_notes/feature/notes/repositories/note_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

import '../../../support/objectbox_test_store.dart';

class MockNoteFileService extends Mock implements NoteFileService {}

class FakeEncryptionService extends Mock implements EncryptionService {
  @override
  Future<String> encrypt(String plainText) async => 'enc:$plainText';

  @override
  Future<String> decrypt(String encryptedText) async {
    if (!encryptedText.startsWith('enc:')) {
      throw const DecryptionException('bad');
    }
    return encryptedText.substring(4);
  }
}

void main() {
  late ObjectBoxTestStore testStore;
  late Directory docs;
  late Directory outside;
  late NoteRepository repository;
  var unlocked = true;

  File makeFile(String path) =>
      File(path)
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('img');

  String image(String name) => p.join(docs.path, 'images', name);
  String bg(String name) => p.join(docs.path, name);

  setUp(() async {
    unlocked = true;
    testStore = await ObjectBoxTestStore.open();
    docs = Directory.systemTemp.createTempSync('kawai_docs_');
    outside = Directory.systemTemp.createTempSync('kawai_outside_');
    final fileService = MockNoteFileService();
    when(() => fileService.deleteNoteFile(any())).thenAnswer((_) async {});
    repository = NoteRepository(
      testStore.service,
      fileService,
      FakeEncryptionService(),
      isHiddenUnlocked: () => unlocked,
      docsDir: () async => docs,
    );
  });

  tearDown(() {
    testStore.close();
    docs.deleteSync(recursive: true);
    outside.deleteSync(recursive: true);
  });

  test('hard delete removes image and background owned only by the note',
      () async {
    final img = makeFile(image('1_a.png'));
    final back = makeFile(bg('note_bg_1.png'));
    final note = await repository.saveNote(
      title: 't',
      content: 'hi\n![image](${img.path})\n',
      customBackgroundImage: back.path,
    );

    await repository.hardDeleteNote(note.id);

    expect(repository.getNote(note.id), isNull);
    expect(img.existsSync(), isFalse);
    expect(back.existsSync(), isFalse);
  });

  test('hard delete keeps media still referenced by another note', () async {
    final img = makeFile(image('2_shared.png'));
    final back = makeFile(bg('note_bg_2.png'));
    final doomed = await repository.saveNote(
      title: 'a',
      content: '![image](${img.path})',
      customBackgroundImage: back.path,
    );
    await repository.saveNote(
      title: 'b',
      content: 'also ![image](${img.path})',
      customBackgroundImage: back.path,
    );

    await repository.hardDeleteNote(doomed.id);

    expect(img.existsSync(), isTrue);
    expect(back.existsSync(), isTrue);
  });

  test('a locked hidden note sharing the image keeps it on disk', () async {
    final img = makeFile(image('3_hidden.png'));
    final doomed = await repository.saveNote(
      title: 'a',
      content: '![image](${img.path})',
    );
    await repository.saveNote(
      title: 'secret',
      content: '![image](${img.path})',
      isHidden: true,
    );
    unlocked = false;

    await repository.hardDeleteNote(doomed.id);

    expect(img.existsSync(), isTrue);
  });

  test('hidden note media is removed only after a successful decrypt',
      () async {
    final img = makeFile(image('4_vault.png'));
    final note = await repository.saveNote(
      title: 'secret',
      content: '![image](${img.path})',
      isHidden: true,
    );

    unlocked = false;
    await repository.hardDeleteNote(note.id);
    expect(repository.getNote(note.id), isNull);
    expect(img.existsSync(), isTrue, reason: 'cannot read refs while locked');

    final img2 = makeFile(image('5_vault.png'));
    unlocked = true;
    final note2 = await repository.saveNote(
      title: 'secret2',
      content: '![image](${img2.path})',
      isHidden: true,
    );
    await repository.hardDeleteNote(note2.id);
    expect(img2.existsSync(), isFalse);
  });

  test('paths outside the app documents dir are never deleted', () async {
    final foreign = makeFile(p.join(outside.path, 'images', 'x.png'));
    final foreignBg = makeFile(p.join(outside.path, 'note_bg_9.png'));
    final traversal = p.join(docs.path, 'images', '..', '..',
        p.basename(outside.path), 'images', 'x.png');
    final note = await repository.saveNote(
      title: 't',
      content: '![image](${foreign.path}) ![image]($traversal)',
      customBackgroundImage: foreignBg.path,
    );

    await repository.hardDeleteNote(note.id);

    expect(foreign.existsSync(), isTrue);
    expect(foreignBg.existsSync(), isTrue);
  });

  test('non-media files in the docs dir are never deleted', () async {
    final db = makeFile(p.join(docs.path, 'notes_db', 'data.mdb'));
    final note = await repository.saveNote(
      title: 't',
      content: '![image](${db.path})',
      customBackgroundImage: db.path,
    );

    await repository.hardDeleteNote(note.id);

    expect(db.existsSync(), isTrue);
  });

  test('symlinks are not followed or deleted', () async {
    final target = makeFile(p.join(outside.path, 'secret.png'));
    final linkPath = image('6_link.png');
    Directory(p.dirname(linkPath)).createSync(recursive: true);
    final link = Link(linkPath)..createSync(target.path);
    final bgLink = Link(bg('note_bg_link.png'))..createSync(target.path);
    final note = await repository.saveNote(
      title: 't',
      content: '![image]($linkPath)',
      customBackgroundImage: bgLink.path,
    );

    await repository.hardDeleteNote(note.id);

    expect(target.existsSync(), isTrue);
    expect(link.existsSync(), isTrue);
    expect(bgLink.existsSync(), isTrue);
  });

  test('trash cleanup also removes owned media', () async {
    final img = makeFile(image('7_old.png'));
    final note = await repository.saveNote(
      title: 't',
      content: '![image](${img.path})',
    );
    final box = testStore.service.store.box<Note>();
    box.put(
      box.get(note.id)!
        ..isDeleted = true
        ..updatedAt = DateTime.now().subtract(const Duration(days: 40)),
    );

    await repository.cleanUpTrashNotes(days: 30);

    expect(repository.getNote(note.id), isNull);
    expect(img.existsSync(), isFalse);
  });

  group('hidden media path rebase (F10)', () {
    const oldDocs = '/data/user/0/old.device/app_flutter';

    test('foreign image paths are rebased after a successful decrypt',
        () async {
      makeFile(image('8_h.png'));
      final note = await repository.saveNote(
        title: 'secret',
        content: 'x ![image]($oldDocs/images/8_h.png) y',
        isHidden: true,
      );
      final before = repository.getNote(note.id)!.updatedAt;

      final content = await repository.getNoteContent(note);

      expect(content, 'x ![image](${image('8_h.png')}) y');
      final stored = repository.getNote(note.id)!;
      expect(stored.content, 'enc:x ![image](${image('8_h.png')}) y');
      expect(stored.updatedAt, before);
    });

    test('paths whose file is missing here are left untouched', () async {
      final note = await repository.saveNote(
        title: 'secret',
        content: '![image]($oldDocs/images/missing.png)',
        isHidden: true,
      );

      final content = await repository.getNoteContent(note);

      expect(content, '![image]($oldDocs/images/missing.png)');
      expect(
        repository.getNote(note.id)!.content,
        'enc:![image]($oldDocs/images/missing.png)',
      );
    });

    test('a locked vault never rewrites the ciphertext', () async {
      makeFile(image('9_h.png'));
      final note = await repository.saveNote(
        title: 'secret',
        content: '![image]($oldDocs/images/9_h.png)',
        isHidden: true,
      );
      unlocked = false;

      await expectLater(
        repository.getNoteContent(note),
        throwsA(isA<HiddenNotesLockedException>()),
      );
      expect(
        repository.getNote(note.id)!.content,
        'enc:![image]($oldDocs/images/9_h.png)',
      );
    });
  });
}
