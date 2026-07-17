import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kawai_notes/feature/notes/services/xiaomi_import_service.dart';

void main() {
  late Directory tempDir;
  late XiaomiImportService service;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('xiaomi_import_test_');
    service = XiaomiImportService();
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  File writeNote(String name, String content) {
    final file = File('${tempDir.path}/$name');
    file.writeAsStringSync(content);
    return file;
  }

  test('parseFile extracts the title and strips the title line', () async {
    final file = writeNote(
      'note_01-02-2024_08-30-00_0001.md',
      '## Title: Shopping list\nMilk\nEggs',
    );

    final result = await service.parseFile(file);

    expect(result!.title, 'Shopping list');
    expect(result.content, 'Milk\nEggs');
  });

  test('falls back to "Untitled" when there is no title line', () async {
    final file = writeNote('note_01-02-2024_08-30-00_0002.md', 'Just content');

    final result = await service.parseFile(file);

    expect(result!.title, 'Untitled');
  });

  test('normalizes a literal "Untitled Note" title to "Untitled"', () async {
    final file = writeNote(
      'note_01-02-2024_08-30-00_0003.md',
      '## Title: Untitled Note\nSome content',
    );

    final result = await service.parseFile(file);

    expect(result!.title, 'Untitled');
  });

  test('strips the "Created at" stamp', () async {
    final file = writeNote(
      'note_01-02-2024_08-30-00_0004.md',
      '## Title: Note\nActual content **Created at: 08/12/2024 12:19**',
    );

    final result = await service.parseFile(file);

    expect(result!.content, 'Actual content');
  });

  test(
    'strips leading "****" markers even when a title line precedes them '
    '(regression test — title removal leaves a leading newline in front of '
    'the asterisks, which the strip regex must tolerate)',
    () async {
      final file = writeNote(
        'note_01-02-2024_08-30-00_0005.md',
        '## Title: Note\n**** Actual content',
      );

      final result = await service.parseFile(file);

      expect(result!.content, 'Actual content');
    },
  );

  test('parses createdAt from the note_DD-MM-YYYY_HH-mm-ss filename pattern', () async {
    final file = writeNote(
      'note_08-12-2024_12-19-00_0178.md',
      '## Title: Note\nBody',
    );

    final result = await service.parseFile(file);

    expect(result!.createdAt, DateTime(2024, 12, 8, 12, 19, 0));
  });

  test('createdAt is null when the filename does not match the pattern', () async {
    final file = writeNote('random-name.md', '## Title: Note\nBody');

    final result = await service.parseFile(file);

    expect(result!.createdAt, isNull);
  });

  test('returns null for a file that does not exist', () async {
    final missing = File('${tempDir.path}/does_not_exist.md');

    final result = await service.parseFile(missing);

    expect(result, isNull);
  });
}
