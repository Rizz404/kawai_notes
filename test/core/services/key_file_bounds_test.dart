import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kawai_notes/core/services/encryption_service.dart';

/// F8: key-file parameters are bounded before any expensive work runs, so a
/// hostile file can neither hang the app nor install a weakly wrapped key.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> secure;

  setUp(() {
    secure = <String, String>{};
    FlutterSecureStorage.setMockInitialValues(secure);
  });

  String keyFile({
    Object? iterations = 210000,
    String? salt,
    String? data,
    String format = 'kawai-key/2',
  }) => jsonEncode({
    'format': format,
    'kdf': 'pbkdf2-hmac-sha256',
    'iterations': iterations,
    'salt': salt ?? base64Encode(List.filled(16, 1)),
    'data': data ?? base64Encode(List.filled(60, 2)),
  });

  Future<void> expectRejected(String file) async {
    final watch = Stopwatch()..start();
    await expectLater(
      EncryptionService().importWrappedKey(file, 'pw'),
      throwsA(isA<KeyImportException>()),
    );
    expect(
      watch.elapsed,
      lessThan(const Duration(seconds: 2)),
      reason: 'rejected before key derivation',
    );
    expect(secure, isEmpty);
  }

  test('iterations below the minimum are rejected', () async {
    await expectRejected(keyFile(iterations: 1));
    await expectRejected(
      keyFile(iterations: EncryptionService.minKeyFileIterations - 1),
    );
  });

  test('iterations above the maximum are rejected quickly', () async {
    await expectRejected(keyFile(iterations: 1000000000));
    await expectRejected(
      keyFile(iterations: EncryptionService.maxKeyFileIterations + 1),
    );
  });

  test('non-integer iterations are rejected', () async {
    await expectRejected(keyFile(iterations: '210000'));
    await expectRejected(keyFile(iterations: 2.5e5));
  });

  /// A correctly wrapped v2 file with chosen salt and payload, so only the
  /// bounds check can reject it.
  Future<String> validFile(List<int> salt, {int keyCount = 1}) async {
    final aes = AesGcm.with256bits();
    final wrapping = await Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: EncryptionService.minKeyFileIterations,
      bits: 256,
    ).deriveKeyFromPassword(password: 'pw', nonce: salt);
    final payload = jsonEncode({
      'keys': [
        for (var i = 0; i < keyCount; i++)
          base64Encode(List.filled(32, i % 256)),
      ],
    });
    final box = await aes.encrypt(utf8.encode(payload), secretKey: wrapping);
    return keyFile(
      iterations: EncryptionService.minKeyFileIterations,
      salt: base64Encode(salt),
      data: base64Encode(box.concatenation()),
    );
  }

  test('salt outside 16..64 bytes is rejected', () async {
    await expectRejected(await validFile(List.filled(4, 1)));
    await expectRejected(await validFile(List.filled(65, 1)));
  });

  test('a validly wrapped file with too many keys is rejected', () async {
    await expectRejected(await validFile(List.filled(16, 1), keyCount: 300));
  });

  test('oversized wrapped data is rejected', () async {
    await expectRejected(
      keyFile(data: base64Encode(List.filled(512 * 1024, 3))),
    );
  });

  test('an oversized key file is rejected before parsing', () async {
    await expectRejected('{"pad":"${'x' * (1024 * 1024)}"}');
  });

  test('export rejects iterations outside the import bounds', () async {
    await EncryptionService().encrypt('seed');
    await expectLater(
      EncryptionService().exportWrappedKey('pw', iterations: 1000),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('a file at the bounds still round-trips', () async {
    final source = EncryptionService();
    final cipher = await source.encrypt('ok');
    final file = await source.exportWrappedKey(
      'pw',
      iterations: EncryptionService.minKeyFileIterations,
    );
    secure.clear();

    await EncryptionService().importWrappedKey(file, 'pw');

    expect(await EncryptionService().decrypt(cipher), 'ok');
  });
}
