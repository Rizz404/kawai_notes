import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kawai_notes/core/services/hidden_notes_auth_service.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mocktail/mocktail.dart';

const _failuresKey = 'hn_auth_failures';

class _MockLocalAuth extends Mock implements LocalAuthentication {}

/// In-memory secure storage whose reads of one key can be made to fail.
class _FlakyStorage extends FlutterSecureStorage {
  final Set<String> failReadsOf = {};
  final Set<String> failWritesOf = {};

  _FlakyStorage();

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) {
    if (failReadsOf.contains(key)) {
      throw PlatformException(code: 'keystore-failed');
    }
    return super.read(key: key);
  }

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
    if (failWritesOf.contains(key)) {
      throw PlatformException(code: 'keystore-failed');
    }
    return super.write(key: key, value: value);
  }
}

/// Lockout robustness: a corrupt or unreadable failure record, a clock moved
/// backwards, concurrent attempts and biometric unlocks must all keep the
/// backoff bounded (it always expires) and fail closed (never a bypass).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> secure;
  late DateTime now;
  late _FlakyStorage storage;
  late _MockLocalAuth localAuth;

  HiddenNotesAuthService service() => HiddenNotesAuthService(
    storage: storage,
    localAuth: localAuth,
    clock: () => now,
  );

  setUp(() {
    secure = <String, String>{};
    FlutterSecureStorage.setMockInitialValues(secure);
    storage = _FlakyStorage();
    localAuth = _MockLocalAuth();
    now = DateTime.utc(2026, 11, 1, 12);
  });

  Future<void> fail(HiddenNotesAuthService s, int times) async {
    for (var i = 0; i < times; i++) {
      expect(await s.verifyPin('0000'), isFalse);
    }
  }

  group('corrupt or unreadable failure record', () {
    for (final raw in [
      'not json',
      jsonEncode({'count': 3}),
      jsonEncode({'count': '5', 'last': 1, 'until': 2}),
      jsonEncode([1, 2, 3]),
    ]) {
      test('a corrupt record locks once, then expires: $raw', () async {
        final s = service();
        await s.setupPin('1234');
        secure[_failuresKey] = raw;

        final first = await s.lockoutRemaining();
        expect(first, greaterThan(Duration.zero), reason: 'fails closed');
        expect(await s.verifyPin('1234'), isFalse);

        now = now.add(first + const Duration(seconds: 1));
        expect(await s.lockoutRemaining(), Duration.zero);
        expect(await s.verifyPin('1234'), isTrue);
      });
    }

    test('a tampered record with an oversized window is bounded', () async {
      final s = service();
      await s.setupPin('1234');
      final ms = now.millisecondsSinceEpoch;
      secure[_failuresKey] = jsonEncode({
        'count': 6,
        'last': ms,
        'until': ms + const Duration(days: 3650).inMilliseconds,
      });

      final remaining = await s.lockoutRemaining();
      expect(remaining, greaterThan(Duration.zero));
      expect(
        remaining,
        lessThanOrEqualTo(HiddenNotesAuthService.maxLockout),
      );
      now = now.add(HiddenNotesAuthService.maxLockout);
      expect(await s.verifyPin('1234'), isTrue);
    });

    test('a record that cannot be read at all still expires and keeps '
        'escalating instead of resetting', () async {
      final s = service();
      await s.setupPin('1234');
      storage.failReadsOf.add(_failuresKey);
      storage.failWritesOf.add(_failuresKey);

      final first = await s.lockoutRemaining();
      expect(first, greaterThan(Duration.zero), reason: 'fails closed');
      expect(await s.verifyPin('1234'), isFalse);
      expect(await s.lockoutRemaining(), lessThanOrEqualTo(first));

      now = now.add(first + const Duration(seconds: 1));
      expect(await s.lockoutRemaining(), Duration.zero);

      // * a wrong guess after the window is not free: the backoff grows
      expect(await s.verifyPin('0000'), isFalse);
      final second = await s.lockoutRemaining();
      expect(second, greaterThan(first));

      now = now.add(second + const Duration(seconds: 1));
      expect(await s.verifyPin('1234'), isTrue);
    });
  });

  test('unreadable but writable storage still escalates after the first '
      'window', () async {
    final s = service();
    await s.setupPin('1234');
    storage.failReadsOf.add(_failuresKey);

    var window = await s.lockoutRemaining();
    for (var i = 0; i < 3; i++) {
      now = now.add(window + const Duration(seconds: 1));
      expect(await s.verifyPin('0000'), isFalse);
      final next = await s.lockoutRemaining();
      expect(next, greaterThan(window), reason: 'attempt $i is counted');
      window = next;
    }
  });

  group('clock moved backwards', () {
    test('the lockout restarts once and then expires', () async {
      final s = service();
      await s.setupPin('1234');
      await fail(s, HiddenNotesAuthService.freeAttempts);
      final full = await s.lockoutRemaining();

      now = now.subtract(const Duration(days: 400));
      expect(await s.lockoutRemaining(), full);
      expect(await s.verifyPin('1234'), isFalse, reason: 'not shortened');

      now = now.add(full + const Duration(seconds: 1));
      expect(await s.lockoutRemaining(), Duration.zero);
      expect(await s.verifyPin('1234'), isTrue);
    });

    test('a restarted window survives an app restart', () async {
      await service().setupPin('1234');
      await fail(service(), HiddenNotesAuthService.freeAttempts);
      final full = await service().lockoutRemaining();

      now = now.subtract(const Duration(days: 1));
      expect(await service().lockoutRemaining(), full);
      now = now.add(const Duration(seconds: 10));

      expect(
        await service().lockoutRemaining(),
        full - const Duration(seconds: 10),
        reason: 'the restart was persisted, not recomputed on every read',
      );
    });
  });

  group('concurrent attempts', () {
    test('a correct guess racing the failure that triggers the lockout is '
        'refused', () async {
      final s = service();
      await s.setupPin('1234');
      await fail(s, HiddenNotesAuthService.freeAttempts - 1);

      final results = await Future.wait([
        s.verifyPin('0000'),
        s.verifyPin('1234'),
      ]);

      expect(results, [false, false]);
      expect(await s.lockoutRemaining(), greaterThan(Duration.zero));
    });

    test('parallel wrong guesses are all counted', () async {
      final s = service();
      await s.setupPin('1234');

      await Future.wait([
        for (var i = 0; i < HiddenNotesAuthService.freeAttempts + 3; i++)
          s.verifyPin('000$i'),
      ]);

      expect(await s.lockoutRemaining(), greaterThan(Duration.zero));
    });

    test('attempts from separate service instances are serialized too',
        () async {
      await service().setupPin('1234');
      await fail(service(), HiddenNotesAuthService.freeAttempts - 1);

      final results = await Future.wait([
        service().verifyPin('0000'),
        service().verifyPin('1234'),
      ]);

      expect(results, [false, false]);
    });

    test('control: sequential use is unchanged', () async {
      final s = service();
      await s.setupPin('1234');
      await fail(s, HiddenNotesAuthService.freeAttempts - 1);
      expect(await s.verifyPin('1234'), isTrue);
      expect(await s.lockoutRemaining(), Duration.zero);
    });
  });

  group('biometric success', () {
    setUp(() {
      when(() => localAuth.canCheckBiometrics).thenAnswer((_) async => true);
      when(() => localAuth.isDeviceSupported()).thenAnswer((_) async => true);
    });

    test('resets the consecutive failure count', () async {
      when(
        () => localAuth.authenticate(
          localizedReason: any(named: 'localizedReason'),
        ),
      ).thenAnswer((_) async => true);
      final s = service();
      await s.setupPin('1234');
      await fail(s, HiddenNotesAuthService.freeAttempts - 1);

      expect(await s.authenticateWithBiometric(), isTrue);
      expect(await s.verifyPin('0000'), isFalse);

      expect(await s.lockoutRemaining(), Duration.zero);
    });

    test('a failed biometric does not reset the count', () async {
      when(
        () => localAuth.authenticate(
          localizedReason: any(named: 'localizedReason'),
        ),
      ).thenAnswer((_) async => false);
      final s = service();
      await s.setupPin('1234');
      await fail(s, HiddenNotesAuthService.freeAttempts - 1);

      expect(await s.authenticateWithBiometric(), isFalse);
      expect(await s.verifyPin('0000'), isFalse);

      expect(await s.lockoutRemaining(), greaterThan(Duration.zero));
    });
  });
}
