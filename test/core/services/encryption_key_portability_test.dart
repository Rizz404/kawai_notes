import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kawai_notes/core/services/encryption_service.dart';

const _keyName = 'kawai_notes_encryption_key';

/// P1 key portability: hidden notes can move to another device through a
/// passphrase-wrapped key file; the key never leaves in plaintext and an
/// existing different key is never overwritten (both are kept).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> secure;

  setUp(() {
    secure = <String, String>{};
    FlutterSecureStorage.setMockInitialValues(secure);
  });

  test(
    'wrapped key round-trips to a fresh device and decrypts old notes',
    () async {
      final source = EncryptionService();
      final ciphertext = await source.encrypt('vault secret');
      final rawKey = secure[_keyName]!;

      final blob = await source.exportWrappedKey(
        'correct horse',
        iterations: EncryptionService.minKeyFileIterations,
      );
      expect(blob, isNot(contains(rawKey)), reason: 'no plaintext key');
      expect(jsonDecode(blob), isA<Map<String, dynamic>>());

      secure.clear(); // * new device
      final target = EncryptionService();
      await target.importWrappedKey(blob, 'correct horse');

      expect(secure[_keyName], rawKey);
      expect(await EncryptionService().decrypt(ciphertext), 'vault secret');
    },
  );

  test('a wrong passphrase is rejected and stores nothing', () async {
    final source = EncryptionService();
    await source.encrypt('seed');
    final blob = await source.exportWrappedKey(
      'right',
      iterations: EncryptionService.minKeyFileIterations,
    );
    secure.clear();

    await expectLater(
      EncryptionService().importWrappedKey(blob, 'wrong'),
      throwsA(isA<KeyImportException>()),
    );
    expect(secure.containsKey(_keyName), isFalse);
  });

  test(
    'a different existing key is kept and the imported key is added',
    () async {
      final source = EncryptionService();
      final importedCipher = await source.encrypt('imported note');
      final blob = await source.exportWrappedKey(
        'pw',
        iterations: EncryptionService.minKeyFileIterations,
      );
      secure.clear();
      final local = EncryptionService();
      final localCipher = await local.encrypt('local note');
      final localKey = secure[_keyName];

      await EncryptionService().importWrappedKey(blob, 'pw');

      expect(secure[_keyName], localKey);
      expect(await EncryptionService().decrypt(localCipher), 'local note');
      expect(
        await EncryptionService().decrypt(importedCipher),
        'imported note',
      );
    },
  );

  test('re-importing the same key is a harmless no-op', () async {
    final service = EncryptionService();
    await service.encrypt('x');
    final key = secure[_keyName];
    final blob = await service.exportWrappedKey(
      'pw',
      iterations: EncryptionService.minKeyFileIterations,
    );

    await EncryptionService().importWrappedKey(blob, 'pw');

    expect(secure[_keyName], key);
  });

  test('malformed key files are rejected', () async {
    await expectLater(
      EncryptionService().importWrappedKey('not json', 'pw'),
      throwsA(isA<KeyImportException>()),
    );
    expect(secure.containsKey(_keyName), isFalse);
  });
}
