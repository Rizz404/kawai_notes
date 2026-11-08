import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kawai_notes/core/services/backup_service.dart';
import 'package:kawai_notes/core/services/notification_service.dart';
import 'package:kawai_notes/core/services/objectbox_service.dart';
import 'package:kawai_notes/feature/notes/models/note.dart';
import 'package:kawai_notes/feature/tasks/repositories/task_repository.dart';
import 'package:kawai_notes/objectbox.g.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

class MockNotificationService extends Mock implements NotificationService {}

/// Stands in for the OS file dialogs: returns a fixed pick, records saves.
class FakeFilePicker extends FilePicker {
  String? pickPath;
  String? saveTarget;
  Uint8List? savedBytes;

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
    final path = pickPath;
    if (path == null) return null;
    return FilePickerResult([
      PlatformFile(
        path: path,
        name: p.basename(path),
        size: File(path).lengthSync(),
      ),
    ]);
  }

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async {
    savedBytes = bytes;
    final target = saveTarget;
    // * mirrors the Android/iOS implementation: the plugin writes the bytes
    if (target != null && bytes != null) {
      File(target).writeAsBytesSync(bytes);
    }
    return target;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory docs;
  late ObjectBoxService svc;
  late BackupService backup;
  late FakeFilePicker picker;

  Note keepNote() => Note(
    ulid: 'u1',
    title: 'Keep',
    contentPath: 'k.md',
    content: 'precious',
  );

  List<String> titles() =>
      svc.store.box<Note>().getAll().map((n) => n.title).toList();

  String autoZipPath() => p.join(docs.path, 'kawai_notes_auto_backup.zip');

  Uint8List zipOf(Map<String, List<int>> entries) {
    final arc = Archive();
    entries.forEach((name, data) {
      arc.addFile(ArchiveFile.bytes(name, data));
    });
    return Uint8List.fromList(ZipEncoder().encode(arc));
  }

  setUp(() async {
    docs = Directory.systemTemp.createTempSync('kawai_backup_docs_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
    picker = FakeFilePicker();
    FilePicker.platform = picker;
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    svc = await ObjectBoxService.create();
    final notif = MockNotificationService();
    when(
      () => notif.showBackupSuccessNotification(
        title: any(named: 'title'),
        body: any(named: 'body'),
      ),
    ).thenAnswer((_) async {});
    backup = BackupService(svc, prefs, notif);
    svc.store.box<Note>().put(keepNote());
  });

  tearDown(() {
    if (!svc.store.isClosed()) svc.store.close();
    if (docs.existsSync()) docs.deleteSync(recursive: true);
  });

  group('auto backup restore validates before touching the live store', () {
    test('non-zip file fails and keeps existing notes', () async {
      File(autoZipPath()).writeAsStringSync('not a zip');

      final ok = await backup.restoreFromAutoBackup();

      expect(ok, isFalse);
      expect(titles(), ['Keep']);
    });

    test('truncated (corrupt) zip fails and keeps existing notes', () async {
      final good = zipOf({
        'notes_db/data.mdb': List<int>.filled(4096, 7),
      });
      File(autoZipPath()).writeAsBytesSync(good.sublist(0, good.length ~/ 2));

      final ok = await backup.restoreFromAutoBackup();

      expect(ok, isFalse);
      expect(titles(), ['Keep']);
    });

    test('valid zip without notes_db fails and keeps existing notes', () async {
      File(autoZipPath()).writeAsBytesSync(
        zipOf({'readme.txt': 'hi'.codeUnits}),
      );

      final ok = await backup.restoreFromAutoBackup();

      expect(ok, isFalse);
      expect(titles(), ['Keep']);
    });

    test('zip with an unopenable notes_db fails and keeps notes', () async {
      File(autoZipPath()).writeAsBytesSync(
        zipOf({'notes_db/data.mdb': List<int>.filled(64, 1)}),
      );

      final ok = await backup.restoreFromAutoBackup();

      expect(ok, isFalse);
      expect(titles(), ['Keep']);
    });

    test('control: backup then restore round-trips notes', () async {
      expect(await backup.runAutoBackup(forceRun: true), isTrue);
      svc.store.box<Note>().put(
        Note(ulid: 'u2', title: 'AfterBackup', contentPath: 'a.md'),
      );
      expect(svc.store.box<Note>().count(), 2);

      final ok = await backup.restoreFromAutoBackup();

      expect(ok, isTrue);
      expect(titles(), ['Keep']);
      // * no leftover staging/rollback directories after success
      final leftovers = docs
          .listSync()
          .map((e) => p.basename(e.path))
          .where((n) => n.contains('.bak') || n.contains('restore_tmp'))
          .toList();
      expect(leftovers, isEmpty);
    });
  });

  group('manual import', () {
    test('bad zip keeps notes_db and the legacy notes/ directory', () async {
      final legacy = Directory(p.join(docs.path, 'notes'))..createSync();
      File(p.join(legacy.path, 'old.md')).writeAsStringSync('legacy');
      final bad = File(p.join(docs.path, 'picked.zip'))
        ..writeAsStringSync('garbage');
      picker.pickPath = bad.path;

      final ok = await backup.importBackupManual();

      expect(ok, isFalse);
      expect(titles(), ['Keep']);
      expect(
        File(p.join(docs.path, 'notes', 'old.md')).readAsStringSync(),
        'legacy',
      );
    });

    test('control: exported backup can be imported back', () async {
      final exportTarget = p.join(docs.path, 'exported.zip');
      picker.saveTarget = exportTarget;
      expect(await backup.exportBackupManual(), isTrue);
      expect(picker.savedBytes, isNotNull);

      svc.store.box<Note>().put(
        Note(ulid: 'u3', title: 'Later', contentPath: 'l.md'),
      );
      picker.pickPath = exportTarget;

      final ok = await backup.importBackupManual();

      expect(ok, isTrue);
      expect(titles(), ['Keep']);
    });
  });

  group('cloud restore', () {
    test('invalid download does not overwrite the good local backup', () async {
      expect(await backup.runAutoBackup(forceRun: true), isTrue);
      final goodBytes = File(autoZipPath()).readAsBytesSync();

      final ok = await backup.restoreFromDownloadedBytes(
        Uint8List.fromList('<html>error</html>'.codeUnits),
      );

      expect(ok, isFalse);
      expect(File(autoZipPath()).readAsBytesSync(), goodBytes);
      expect(titles(), ['Keep']);
    });
  });

  group('backup content (F8)', () {
    test('backup includes images/ and note background files', () async {
      final images = Directory(p.join(docs.path, 'images'))..createSync();
      File(p.join(images.path, '1_a.png')).writeAsBytesSync([1, 2, 3]);
      File(p.join(docs.path, 'note_bg_5.jpg')).writeAsBytesSync([4, 5]);
      File(p.join(docs.path, 'note_bg_batch_6.png')).writeAsBytesSync([6]);

      expect(await backup.runAutoBackup(forceRun: true), isTrue);

      final names = ZipDecoder()
          .decodeBytes(File(autoZipPath()).readAsBytesSync())
          .map((f) => f.name)
          .toList();
      expect(names, contains('images/1_a.png'));
      expect(names, contains('note_bg_5.jpg'));
      expect(names, contains('note_bg_batch_6.png'));
      expect(names, contains('notes_db/data.mdb'));
    });

    test('restore brings media back and rebases absolute paths', () async {
      final oldDocs = '/data/user/0/old.device/app_flutter';
      final box = svc.store.box<Note>();
      box.removeAll();
      box.put(
        Note(
          ulid: 'm1',
          title: 'Media',
          contentPath: 'm.md',
          content: 'hello\n![image]($oldDocs/images/1_a.png)\n',
          customBackgroundImage: '$oldDocs/note_bg_5.jpg',
        ),
      );
      final images = Directory(p.join(docs.path, 'images'))..createSync();
      File(p.join(images.path, '1_a.png')).writeAsBytesSync([1, 2, 3]);
      File(p.join(docs.path, 'note_bg_5.jpg')).writeAsBytesSync([4, 5]);
      expect(await backup.runAutoBackup(forceRun: true), isTrue);

      // * simulate a fresh device: media gone
      images.deleteSync(recursive: true);
      File(p.join(docs.path, 'note_bg_5.jpg')).deleteSync();

      expect(await backup.restoreFromAutoBackup(), isTrue);

      expect(
        File(p.join(docs.path, 'images', '1_a.png')).readAsBytesSync(),
        [1, 2, 3],
      );
      expect(File(p.join(docs.path, 'note_bg_5.jpg')).existsSync(), isTrue);
      final note = svc.store.box<Note>().getAll().single;
      expect(
        note.content,
        'hello\n![image](${p.join(docs.path, 'images', '1_a.png')})\n',
      );
      expect(
        note.customBackgroundImage,
        p.join(docs.path, 'note_bg_5.jpg'),
      );
    });

    test('auto backup keeps the previous zip as .prev (rotation)', () async {
      expect(await backup.runAutoBackup(forceRun: true), isTrue);
      final first = File(autoZipPath()).readAsBytesSync();
      svc.store.box<Note>().put(
        Note(ulid: 'u9', title: 'Second', contentPath: 's.md'),
      );

      expect(await backup.runAutoBackup(forceRun: true), isTrue);

      expect(File('${autoZipPath()}.prev').readAsBytesSync(), first);
      expect(File('${autoZipPath()}.tmp').existsSync(), isFalse);
    });

    test('legacy backup with only notes_db is still restorable', () async {
      expect(await backup.runAutoBackup(forceRun: true), isTrue);
      final full = ZipDecoder().decodeBytes(
        File(autoZipPath()).readAsBytesSync(),
      );
      final legacy = Archive();
      for (final f in full) {
        if (f.isFile && f.name.startsWith('notes_db/')) {
          legacy.addFile(ArchiveFile.bytes(f.name, f.readBytes()!));
        }
      }
      File(autoZipPath()).writeAsBytesSync(ZipEncoder().encode(legacy));
      svc.store.box<Note>().put(
        Note(ulid: 'u8', title: 'Extra', contentPath: 'e.md'),
      );

      expect(await backup.restoreFromAutoBackup(), isTrue);
      expect(titles(), ['Keep']);
    });
  });

  group('archive size bounds (F8)', () {
    late MockNotificationService notif;
    late SharedPreferences prefs;

    setUp(() async {
      notif = MockNotificationService();
      prefs = await SharedPreferences.getInstance();
    });

    BackupService limited(BackupLimits limits) =>
        BackupService(svc, prefs, notif, limits: limits);

    Future<Uint8List> validBackup() async {
      expect(await backup.runAutoBackup(forceRun: true), isTrue);
      svc.store.box<Note>().put(
        Note(ulid: 'later', title: 'Later', contentPath: 'l.md'),
      );
      return File(autoZipPath()).readAsBytesSync();
    }

    int dbSize(Uint8List zip) => ZipDecoder()
        .decodeBytes(zip)
        .findFile('notes_db/data.mdb')!
        .size;

    test('control: generous limits restore a real backup', () async {
      await validBackup();
      final ok = await limited(
        const BackupLimits(
          maxArchiveBytes: 1 << 30,
          maxEntryBytes: 1 << 30,
          maxTotalBytes: 1 << 30,
          maxEntries: 1000,
        ),
      ).restoreFromAutoBackup();
      expect(ok, isTrue);
      expect(titles(), ['Keep']);
    });

    test('zip file larger than the archive cap is rejected', () async {
      final zip = await validBackup();
      final ok = await limited(
        BackupLimits(
          maxArchiveBytes: zip.length - 1,
          maxEntryBytes: 1 << 30,
          maxTotalBytes: 1 << 30,
          maxEntries: 1000,
        ),
      ).restoreFromAutoBackup();
      expect(ok, isFalse);
      expect(titles(), containsAll(['Keep', 'Later']));
    });

    test('entry larger than the per-entry cap is rejected', () async {
      final zip = await validBackup();
      final ok = await limited(
        BackupLimits(
          maxArchiveBytes: 1 << 30,
          maxEntryBytes: dbSize(zip) - 1,
          maxTotalBytes: 1 << 30,
          maxEntries: 1000,
        ),
      ).restoreFromAutoBackup();
      expect(ok, isFalse);
      expect(titles(), containsAll(['Keep', 'Later']));
    });

    test('total uncompressed size above the cap is rejected', () async {
      final zip = await validBackup();
      final ok = await limited(
        BackupLimits(
          maxArchiveBytes: 1 << 30,
          maxEntryBytes: 1 << 30,
          maxTotalBytes: dbSize(zip) - 1,
          maxEntries: 1000,
        ),
      ).restoreFromAutoBackup();
      expect(ok, isFalse);
      expect(titles(), containsAll(['Keep', 'Later']));
    });

    test('too many entries are rejected', () async {
      File(p.join(docs.path, 'note_bg_1.png')).writeAsBytesSync([1]);
      await validBackup();
      final ok = await limited(
        const BackupLimits(
          maxArchiveBytes: 1 << 30,
          maxEntryBytes: 1 << 30,
          maxTotalBytes: 1 << 30,
          maxEntries: 1,
        ),
      ).restoreFromAutoBackup();
      expect(ok, isFalse);
      expect(titles(), containsAll(['Keep', 'Later']));
    });

    test('entry that lies about its size is stopped while inflating', () async {
      // * 64 KiB of zeros deflates to a few bytes; then the declared
      // * uncompressed size in both headers is forged down to 16 bytes.
      final arc = Archive()
        ..addFile(ArchiveFile.bytes('notes_db/data.mdb', List.filled(65536, 0)));
      final bytes = Uint8List.fromList(ZipEncoder().encode(arc));
      final bd = ByteData.sublistView(bytes);
      for (var i = 0; i + 4 <= bytes.length; i++) {
        final sig = bd.getUint32(i, Endian.little);
        if (sig == 0x04034b50) bd.setUint32(i + 22, 16, Endian.little);
        if (sig == 0x02014b50) bd.setUint32(i + 24, 16, Endian.little);
      }
      File(autoZipPath()).writeAsBytesSync(bytes);

      final ok = await limited(
        const BackupLimits(
          maxArchiveBytes: 1 << 30,
          maxEntryBytes: 1024,
          maxTotalBytes: 1 << 30,
          maxEntries: 1000,
        ),
      ).restoreFromAutoBackup();

      expect(ok, isFalse);
      expect(titles(), ['Keep']);
      expect(
        docs.listSync().where((e) => e.path.contains('restore_tmp')),
        isEmpty,
      );
    });

    test('downloaded bytes above the archive cap are rejected', () async {
      final zip = await validBackup();
      final ok = await limited(
        BackupLimits(
          maxArchiveBytes: zip.length - 1,
          maxEntryBytes: 1 << 30,
          maxTotalBytes: 1 << 30,
          maxEntries: 1000,
        ),
      ).restoreFromDownloadedBytes(zip);
      expect(ok, isFalse);
      expect(titles(), containsAll(['Keep', 'Later']));
    });
  });

  group('backup snapshot consistency (F9)', () {
    Future<Directory> extractDb(String zipPath) async {
      final out = Directory.systemTemp.createTempSync('kawai_probe_');
      for (final f in ZipDecoder().decodeBytes(File(zipPath).readAsBytesSync())) {
        if (!f.isFile || !f.name.startsWith('notes_db/')) continue;
        File(p.join(out.path, f.name))
          ..parent.createSync(recursive: true)
          ..writeAsBytesSync(f.readBytes()!);
      }
      return Directory(p.join(out.path, 'notes_db'));
    }

    test('created backup holds an openable db snapshot without lock.mdb',
        () async {
      expect(await backup.runAutoBackup(forceRun: true), isTrue);

      final names = ZipDecoder()
          .decodeBytes(File(autoZipPath()).readAsBytesSync())
          .map((f) => f.name)
          .toList();
      expect(names, isNot(contains('notes_db/lock.mdb')));

      final dbDir = await extractDb(autoZipPath());
      final probe = await openStore(directory: dbDir.path);
      expect(probe.box<Note>().getAll().map((n) => n.title), ['Keep']);
      probe.close();
      dbDir.parent.deleteSync(recursive: true);
    });

    test('writes racing the snapshot are not torn into the backup', () async {
      backup.debugAfterSnapshot = (_) async {
        svc.store.box<Note>().put(
          Note(ulid: 'race', title: 'Racing', contentPath: 'r.md'),
        );
      };

      expect(await backup.runAutoBackup(forceRun: true), isTrue);

      final dbDir = await extractDb(autoZipPath());
      final probe = await openStore(directory: dbDir.path);
      expect(probe.box<Note>().getAll().map((n) => n.title), ['Keep']);
      probe.close();
      dbDir.parent.deleteSync(recursive: true);
      expect(titles(), containsAll(['Keep', 'Racing']));
    });

    test('a backup whose db cannot be opened is discarded', () async {
      expect(await backup.runAutoBackup(forceRun: true), isTrue);
      final good = File(autoZipPath()).readAsBytesSync();
      backup.debugAfterSnapshot = (snapshot) async {
        File(p.join(snapshot.path, 'data.mdb'))
            .writeAsBytesSync(List<int>.filled(64, 1));
      };

      expect(await backup.runAutoBackup(forceRun: true), isFalse);

      expect(File(autoZipPath()).readAsBytesSync(), good);
      expect(File('${autoZipPath()}.tmp').existsSync(), isFalse);
      final leftovers = docs
          .listSync()
          .map((e) => p.basename(e.path))
          .where((n) => n.startsWith('.backup_'))
          .toList();
      expect(leftovers, isEmpty);
    });
  });

  group('restore quiesces store users (F11)', () {
    test('a write racing the swap is rejected with a typed error', () async {
      expect(await backup.runAutoBackup(forceRun: true), isTrue);
      final tasks = TaskRepository(svc);
      Object? raced;
      backup.debugDuringSwap = () async {
        expect(svc.isRestoring, isTrue);
        try {
          tasks.saveTask(title: 'mid-restore');
        } catch (e) {
          raced = e;
        }
      };

      expect(await backup.restoreFromAutoBackup(), isTrue);

      expect(raced, isA<StoreRestoringException>());
      expect(svc.isRestoring, isFalse);
      expect(tasks.getAllTasks(), isEmpty);
      expect(titles(), ['Keep']);
      tasks.saveTask(title: 'after');
      expect(tasks.getAllTasks().map((t) => t.title), ['after']);
    });

    test('backup creation during a restore fails instead of hitting a '
        'closed store', () async {
      expect(await backup.runAutoBackup(forceRun: true), isTrue);
      bool? concurrent;
      backup.debugDuringSwap = () async {
        concurrent = await backup.runAutoBackup(forceRun: true);
      };

      expect(await backup.restoreFromAutoBackup(), isTrue);
      expect(concurrent, isFalse);
    });

    test('quiesce hooks run before the store closes', () async {
      expect(await backup.runAutoBackup(forceRun: true), isTrue);
      final events = <String>[];
      svc.addQuiesceHook(() async {
        events.add('hook:${svc.store.isClosed() ? 'closed' : 'open'}');
        svc.store.box<Note>().put(
          Note(ulid: 'flush', title: 'Flushed', contentPath: 'f.md'),
        );
      });
      backup.debugDuringSwap = () async => events.add('swap');

      expect(await backup.restoreFromAutoBackup(), isTrue);

      expect(events, ['hook:open', 'swap']);
      // * the restored snapshot replaces whatever the hook flushed
      expect(titles(), ['Keep']);
    });

    test('a failing swap rolls back and the store is usable again', () async {
      expect(await backup.runAutoBackup(forceRun: true), isTrue);
      svc.store.box<Note>().put(
        Note(ulid: 'live', title: 'Live', contentPath: 'l.md'),
      );
      backup.debugDuringSwap = () async => throw StateError('disk full');

      expect(await backup.restoreFromAutoBackup(), isFalse);

      expect(svc.isRestoring, isFalse);
      expect(titles(), containsAll(['Keep', 'Live']));
      svc.store.box<Note>().put(
        Note(ulid: 'post', title: 'Post', contentPath: 'p.md'),
      );
      expect(titles(), contains('Post'));
    });
  });
}
