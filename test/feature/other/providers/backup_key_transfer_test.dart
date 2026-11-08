import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kawai_notes/core/services/encryption_service.dart';
import 'package:kawai_notes/feature/other/providers/backup_provider.dart';
import 'package:path/path.dart' as p;

const _keyName = 'kawai_notes_encryption_key';

/// Stands in for the OS file dialogs.
class FakeFilePicker extends FilePicker {
  String? pickPath;
  Uint8List? savedBytes;
  String? savedName;

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
    savedName = fileName;
    return '/picked/$fileName';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> secure;
  late FakeFilePicker picker;
  late Directory tmp;
  late ProviderContainer container;

  setUp(() {
    secure = <String, String>{};
    FlutterSecureStorage.setMockInitialValues(secure);
    picker = FakeFilePicker();
    FilePicker.platform = picker;
    tmp = Directory.systemTemp.createTempSync('kawai_key_transfer_');
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
    tmp.deleteSync(recursive: true);
  });

  test('exported key file restores hidden notes on a new device', () async {
    final ciphertext = await EncryptionService().encrypt('vault');
    final rawKey = secure[_keyName]!;

    final exported = await container
        .read(backupProvider.notifier)
        .exportEncryptionKey('pass phrase');
    expect(exported, isTrue);
    final file = File(p.join(tmp.path, picker.savedName!))
      ..writeAsBytesSync(picker.savedBytes!);
    expect(file.readAsStringSync(), isNot(contains(rawKey)));

    secure.clear(); // * new device
    picker.pickPath = file.path;
    final fresh = ProviderContainer();
    addTearDown(fresh.dispose);

    final imported = await fresh
        .read(backupProvider.notifier)
        .importEncryptionKey('pass phrase');

    expect(imported, isTrue);
    expect(await EncryptionService().decrypt(ciphertext), 'vault');
  });

  test('a wrong passphrase reports failure and stores no key', () async {
    await EncryptionService().encrypt('vault');
    await container.read(backupProvider.notifier).exportEncryptionKey('right');
    final file = File(p.join(tmp.path, 'k.key'))
      ..writeAsBytesSync(picker.savedBytes!);
    secure.clear();
    picker.pickPath = file.path;

    final imported = await container
        .read(backupProvider.notifier)
        .importEncryptionKey('wrong');

    expect(imported, isFalse);
    expect(secure.containsKey(_keyName), isFalse);
  });
}
