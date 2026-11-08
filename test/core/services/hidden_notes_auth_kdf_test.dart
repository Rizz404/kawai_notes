import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kawai_notes/core/services/hidden_notes_auth_service.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mocktail/mocktail.dart';

const _pinKey = 'hn_auth_pin_hash';
const _passwordKey = 'hn_auth_password_hash';
const _patternKey = 'hn_auth_pattern_hash';

class _MockLocalAuth extends Mock implements LocalAuthentication {}

/// Delegates to the in-memory secure storage but can fail writes on demand.
class _FlakyStorage extends FlutterSecureStorage {
  bool failWrites = false;

  _FlakyStorage();

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) {
    if (failWrites) throw PlatformException(code: 'storage-failed');
    return super.write(key: key, value: value);
  }
}

String _legacy(String v) => sha256.convert(utf8.encode(v)).toString();

/// F2: credentials use a versioned, salted, slow KDF; legacy SHA-256 values
/// keep working and are upgraded only after a successful verify; repeated
/// failures back off on a persisted, clock-injected schedule.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> secure;
  late DateTime now;
  late _FlakyStorage storage;

  HiddenNotesAuthService service() => HiddenNotesAuthService(
    storage: storage,
    localAuth: _MockLocalAuth(),
    clock: () => now,
  );

  setUp(() {
    secure = <String, String>{};
    FlutterSecureStorage.setMockInitialValues(secure);
    storage = _FlakyStorage();
    now = DateTime.utc(2026, 11, 1, 12);
  });

  group('versioned salted KDF', () {
    test('stored PIN is a v2 PBKDF2 record with a random salt', () async {
      await service().setupPin('1234');
      final first = secure[_pinKey]!;
      await service().setupPin('1234');
      final second = secure[_pinKey]!;

      expect(first, isNot(second), reason: 'per-credential random salt');
      expect(first, isNot(contains(_legacy('1234'))));
      final record = jsonDecode(first) as Map<String, dynamic>;
      expect(record['v'], 2);
      expect(record['kdf'], 'pbkdf2-hmac-sha256');
      expect(
        record['iter'],
        greaterThanOrEqualTo(HiddenNotesAuthService.minIterations),
      );
      expect(base64Decode(record['salt'] as String).length, 16);
      expect(base64Decode(record['hash'] as String).length, 32);
    });

    test('PIN, pattern and password verify only the right value', () async {
      final s = service();
      await s.setupPin('1234');
      await s.setupPattern([0, 1, 2, 5]);
      await s.setupPassword('hunter2');

      expect(await s.verifyPin('1234'), isTrue);
      expect(await s.verifyPin('1235'), isFalse);
      expect(await s.verifyPattern([0, 1, 2, 5]), isTrue);
      expect(await s.verifyPattern([0, 1, 2]), isFalse);
      expect(await s.verifyPassword('hunter2'), isTrue);
      expect(await s.verifyPassword('Hunter2'), isFalse);
    });

    test('malformed or out-of-bounds records never verify', () async {
      final bad = <String>[
        'not json',
        jsonEncode({'v': 2}),
        jsonEncode({
          'v': 2,
          'kdf': 'pbkdf2-hmac-sha256',
          'iter': 1,
          'salt': base64Encode(List.filled(16, 0)),
          'hash': base64Encode(List.filled(32, 0)),
        }),
        jsonEncode({
          'v': 2,
          'kdf': 'pbkdf2-hmac-sha256',
          'iter': 1000000000,
          'salt': base64Encode(List.filled(16, 0)),
          'hash': base64Encode(List.filled(32, 0)),
        }),
        jsonEncode({
          'v': 2,
          'kdf': 'pbkdf2-hmac-sha256',
          'iter': HiddenNotesAuthService.minIterations,
          'salt': base64Encode(List.filled(2, 0)),
          'hash': base64Encode(List.filled(32, 0)),
        }),
        jsonEncode({
          'v': 9,
          'kdf': 'pbkdf2-hmac-sha256',
          'iter': HiddenNotesAuthService.minIterations,
          'salt': base64Encode(List.filled(16, 0)),
          'hash': base64Encode(List.filled(32, 0)),
        }),
      ];
      for (final record in bad) {
        secure[_pinKey] = record;
        final watch = Stopwatch()..start();
        expect(await service().verifyPin('1234'), isFalse, reason: record);
        expect(watch.elapsed, lessThan(const Duration(seconds: 3)));
        now = now.add(const Duration(hours: 2)); // * skip any backoff
      }
    });
  });

  group('legacy SHA-256 upgrade', () {
    test('a legacy PIN verifies and is then upgraded to v2', () async {
      secure[_pinKey] = _legacy('1234');

      expect(await service().verifyPin('1234'), isTrue);

      final upgraded = jsonDecode(secure[_pinKey]!) as Map<String, dynamic>;
      expect(upgraded['v'], 2);
      expect(await service().verifyPin('1234'), isTrue);
    });

    test('a wrong legacy PIN does not upgrade the record', () async {
      secure[_pinKey] = _legacy('1234');

      expect(await service().verifyPin('0000'), isFalse);

      expect(secure[_pinKey], _legacy('1234'));
    });

    test('legacy pattern and password upgrade too', () async {
      secure[_patternKey] = _legacy('0,1,2,5');
      secure[_passwordKey] = _legacy('pw');

      expect(await service().verifyPattern([0, 1, 2, 5]), isTrue);
      expect(await service().verifyPassword('pw'), isTrue);

      expect(jsonDecode(secure[_patternKey]!)['v'], 2);
      expect(jsonDecode(secure[_passwordKey]!)['v'], 2);
    });

    test('an upgrade write failure keeps the legacy record usable', () async {
      secure[_pinKey] = _legacy('1234');
      storage.failWrites = true;

      expect(await service().verifyPin('1234'), isTrue);
      expect(secure[_pinKey], _legacy('1234'));

      storage.failWrites = false;
      expect(await service().verifyPin('1234'), isTrue);
      expect(jsonDecode(secure[_pinKey]!)['v'], 2);
    });

    test('a failed setup leaves the previous credential intact', () async {
      await service().setupPin('1234');
      final before = secure[_pinKey];
      storage.failWrites = true;

      await expectLater(service().setupPin('9999'), throwsA(anything));

      expect(secure[_pinKey], before);
      storage.failWrites = false;
      expect(await service().verifyPin('1234'), isTrue);
    });
  });

  group('failed-attempt backoff', () {
    test('after 5 failures even the right PIN is refused until the delay',
        () async {
      final s = service();
      await s.setupPin('1234');
      for (var i = 0; i < HiddenNotesAuthService.freeAttempts; i++) {
        expect(await s.verifyPin('0000'), isFalse);
      }

      expect(await s.lockoutRemaining(), greaterThan(Duration.zero));
      expect(await s.verifyPin('1234'), isFalse, reason: 'backoff active');

      now = now.add(await s.lockoutRemaining());
      expect(await s.lockoutRemaining(), Duration.zero);
      expect(await s.verifyPin('1234'), isTrue);
    });

    test('backoff doubles with further failures and is capped', () async {
      final s = service();
      await s.setupPin('1234');
      for (var i = 0; i < HiddenNotesAuthService.freeAttempts; i++) {
        await s.verifyPin('0000');
      }
      final first = await s.lockoutRemaining();
      now = now.add(first);
      await s.verifyPin('0000');
      final second = await s.lockoutRemaining();

      expect(second, first * 2);
      for (var i = 0; i < 12; i++) {
        now = now.add(await s.lockoutRemaining());
        await s.verifyPin('0000');
      }
      expect(
        await s.lockoutRemaining(),
        lessThanOrEqualTo(HiddenNotesAuthService.maxLockout),
      );
    });

    test('a success resets the failure count', () async {
      final s = service();
      await s.setupPin('1234');
      for (var i = 0; i < HiddenNotesAuthService.freeAttempts - 1; i++) {
        await s.verifyPin('0000');
      }
      expect(await s.verifyPin('1234'), isTrue);
      expect(await s.verifyPin('0000'), isFalse);
      expect(await s.lockoutRemaining(), Duration.zero);
    });

    test('restarting the app does not reset the backoff', () async {
      await service().setupPin('1234');
      for (var i = 0; i < HiddenNotesAuthService.freeAttempts; i++) {
        await service().verifyPin('0000');
      }

      final restarted = service();
      expect(await restarted.lockoutRemaining(), greaterThan(Duration.zero));
      expect(await restarted.verifyPin('1234'), isFalse);
    });

    test('moving the clock backwards does not end the lockout', () async {
      final s = service();
      await s.setupPin('1234');
      for (var i = 0; i < HiddenNotesAuthService.freeAttempts; i++) {
        await s.verifyPin('0000');
      }
      final remaining = await s.lockoutRemaining();

      now = now.subtract(const Duration(days: 1));

      expect(await s.lockoutRemaining(), greaterThanOrEqualTo(remaining));
      expect(await s.verifyPin('1234'), isFalse);
    });

    test('backoff applies across PIN, pattern and password', () async {
      final s = service();
      await s.setupPin('1234');
      await s.setupPassword('pw');
      for (var i = 0; i < HiddenNotesAuthService.freeAttempts; i++) {
        await s.verifyPin('0000');
      }

      expect(await s.verifyPassword('pw'), isFalse);
    });
  });
}
