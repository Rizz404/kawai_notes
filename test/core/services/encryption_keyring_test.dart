import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kawai_notes/core/services/encryption_service.dart';
import 'package:mocktail/mocktail.dart';

const _keyName = 'kawai_notes_encryption_key';
const _iterations = EncryptionService.minKeyFileIterations;

class _UnavailableStorage extends Mock implements FlutterSecureStorage {}

/// Builds a key file exactly as the previous release (kawai-key/1) did.
Future<String> _wrapLegacy(
  List<int> rawKey,
  String passphrase,
  int iterations,
) async {
  final aes = AesGcm.with256bits();
  final salt = SecretKeyData.random(length: 16).bytes;
  final wrapping = await Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: iterations,
    bits: 256,
  ).deriveKeyFromPassword(password: passphrase, nonce: salt);
  final box = await aes.encrypt(rawKey, secretKey: wrapping);
  return jsonEncode({
    'format': 'kawai-key/1',
    'kdf': 'pbkdf2-hmac-sha256',
    'iterations': iterations,
    'salt': base64Encode(salt),
    'data': base64Encode(box.concatenation()),
  });
}

/// F5: export never creates a key, and importing a key file never discards
/// or replaces a key that existing ciphertext depends on.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> secure;

  setUp(() {
    secure = <String, String>{};
    FlutterSecureStorage.setMockInitialValues(secure);
  });

  test('export with no key throws and creates no key', () async {
    await expectLater(
      EncryptionService().exportWrappedKey('pw', iterations: _iterations),
      throwsA(isA<KeyExportException>()),
    );
    expect(secure, isEmpty);
    expect(await EncryptionService().hasKey(), isFalse);
  });

  test(
    'old-key backup restores after a new key was created on the new device',
    () async {
      final oldDevice = EncryptionService();
      final oldCipher = await oldDevice.encrypt('old secret');
      final keyFile = await oldDevice.exportWrappedKey(
        'pw',
        iterations: _iterations,
      );

      secure.clear(); // * new device
      final newDevice = EncryptionService();
      final newCipher = await newDevice.encrypt('new secret');
      final newKey = secure[_keyName];

      await newDevice.importWrappedKey(keyFile, 'pw');

      expect(secure[_keyName], newKey, reason: 'current key is kept');
      expect(await newDevice.decrypt(oldCipher), 'old secret');
      expect(await newDevice.decrypt(newCipher), 'new secret');
      // * persisted: a fresh service instance (app restart) reads both
      expect(await EncryptionService().decrypt(oldCipher), 'old secret');
      expect(await EncryptionService().decrypt(newCipher), 'new secret');
    },
  );

  test('export after a merge carries every key to the next device', () async {
    final a = EncryptionService();
    final cipherA = await a.encrypt('from A');
    final fileA = await a.exportWrappedKey('pw', iterations: _iterations);

    secure.clear();
    final b = EncryptionService();
    final cipherB = await b.encrypt('from B');
    await b.importWrappedKey(fileA, 'pw');
    final merged = await b.exportWrappedKey('pw2', iterations: _iterations);

    secure.clear(); // * third device
    final c = EncryptionService();
    await c.importWrappedKey(merged, 'pw2');

    expect(await c.decrypt(cipherA), 'from A');
    expect(await c.decrypt(cipherB), 'from B');
  });

  test('legacy single-key files (kawai-key/1) still import', () async {
    final source = EncryptionService();
    final cipher = await source.encrypt('legacy');
    final rawKey = base64Decode(secure[_keyName]!);
    final legacyFile = await _wrapLegacy(rawKey, 'pw', _iterations);
    expect(jsonDecode(legacyFile)['format'], 'kawai-key/1');

    secure.clear();
    await EncryptionService().encrypt('other');
    await EncryptionService().importWrappedKey(legacyFile, 'pw');

    expect(await EncryptionService().decrypt(cipher), 'legacy');
  });

  test(
    'wrong passphrase changes nothing and keeps existing notes readable',
    () async {
      final file = await (() async {
        final s = EncryptionService();
        await s.encrypt('x');
        return s.exportWrappedKey('right', iterations: _iterations);
      })();
      secure.clear();
      final local = EncryptionService();
      final localCipher = await local.encrypt('local');
      final before = Map<String, String>.of(secure);

      await expectLater(
        local.importWrappedKey(file, 'wrong'),
        throwsA(isA<KeyImportException>()),
      );

      expect(secure, before);
      expect(await EncryptionService().decrypt(localCipher), 'local');
    },
  );

  test('concurrent import and hide keep both keys usable', () async {
    final source = EncryptionService();
    final oldCipher = await source.encrypt('old');
    final file = await source.exportWrappedKey('pw', iterations: _iterations);

    secure.clear();
    final service = EncryptionService();
    final results = await Future.wait<Object?>([
      service.importWrappedKey(file, 'pw'),
      service.encrypt('hidden during import'),
    ]);
    final newCipher = results[1]! as String;

    expect(await EncryptionService().decrypt(oldCipher), 'old');
    expect(
      await EncryptionService().decrypt(newCipher),
      'hidden during import',
    );
  });

  test(
    'unavailable secure storage fails closed without creating keys',
    () async {
      final storage = _UnavailableStorage();
      when(
        () => storage.read(key: any(named: 'key')),
      ).thenThrow(PlatformException(code: 'unavailable'));
      when(
        () => storage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenThrow(PlatformException(code: 'unavailable'));
      final service = EncryptionService(storage: storage);

      await expectLater(
        service.exportWrappedKey('pw', iterations: _iterations),
        throwsA(isA<KeyExportException>()),
      );
      await expectLater(
        service.importWrappedKey('{}', 'pw'),
        throwsA(isA<KeyImportException>()),
      );
      await expectLater(
        service.decrypt('AAAA'),
        throwsA(isA<DecryptionException>()),
      );
      verifyNever(
        () => storage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      );
    },
  );
}
