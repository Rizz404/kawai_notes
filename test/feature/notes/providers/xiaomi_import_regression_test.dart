import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kawai_notes/core/services/encryption_service.dart';
import 'package:kawai_notes/core/services/note_file_service.dart';
import 'package:kawai_notes/di/repository_providers.dart';
import 'package:kawai_notes/feature/notes/providers/xiaomi_import_provider.dart';
import 'package:kawai_notes/feature/notes/repositories/note_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

import '../../../support/objectbox_test_store.dart';

class MockNoteFileService extends Mock implements NoteFileService {}

class MockEncryptionService extends Mock implements EncryptionService {}

class _MultiPicker extends FilePicker {
  List<String> paths = [];

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    void Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    return FilePickerResult([
      for (final path in paths)
        PlatformFile(
          path: path,
          name: p.basename(path),
          size: File(path).lengthSync(),
        ),
    ]);
  }
}

/// F13: bulk import must not silently drop files beyond 50, and
/// re-importing the same files must not duplicate notes.
void main() {
  late ObjectBoxTestStore testStore;
  late NoteRepository notes;
  late ProviderContainer container;
  late Directory dir;
  late _MultiPicker picker;

  setUp(() async {
    testStore = await ObjectBoxTestStore.open();
    notes = NoteRepository(
      testStore.service,
      MockNoteFileService(),
      MockEncryptionService(),
    );
    container = ProviderContainer(
      overrides: [noteRepositoryProvider.overrideWithValue(notes)],
    );
    dir = Directory.systemTemp.createTempSync('kawai_xiaomi_');
    picker = _MultiPicker();
    FilePicker.platform = picker;
    for (var i = 0; i < 51; i++) {
      final n = i.toString().padLeft(2, '0');
      final f = File(p.join(dir.path, 'note_08-12-2024_12-19-$n.md'));
      f.writeAsStringSync('## Title: Note $n\n****\nBody $n\n');
      picker.paths.add(f.path);
    }
  });

  tearDown(() {
    container.dispose();
    testStore.close();
    dir.deleteSync(recursive: true);
  });

  Future<bool> runImport() async {
    final sub = container.listen(xiaomiImportProvider, (_, _) {});
    final ok = await container
        .read(xiaomiImportProvider.notifier)
        .importXiaomiNotesBulk();
    sub.close();
    return ok;
  }

  test('all 51 picked files are imported', () async {
    expect(await runImport(), isTrue);
    expect(notes.getAllNotes(), hasLength(51));
  });

  test('re-importing the same files does not duplicate notes', () async {
    await runImport();
    await runImport();
    expect(notes.getAllNotes(), hasLength(51));
  });

  test('F12c re-import dedupes notes whose filename has no date', () async {
    picker.paths = [];
    for (final name in ['plain_a.md', 'plain_b.md']) {
      final f = File(p.join(dir.path, name));
      f.writeAsStringSync('## Title: $name\n****\nUndated body\n');
      picker.paths.add(f.path);
    }

    await runImport();
    await runImport();

    expect(notes.getAllNotes(), hasLength(2));
  });

  test('F12c undated notes with distinct content are both kept', () async {
    picker.paths = [];
    for (final body in ['one', 'two']) {
      final f = File(p.join(dir.path, 'undated_$body.md'));
      f.writeAsStringSync('## Title: Same\n****\n$body\n');
      picker.paths.add(f.path);
    }

    await runImport();

    expect(notes.getAllNotes(), hasLength(2));
  });
}
