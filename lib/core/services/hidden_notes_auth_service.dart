import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

enum HiddenNotesAuthMethod { biometric, pin, pattern, password }

/// Hidden-notes credentials (PIN, pattern, password).
///
/// Values are stored as a versioned PBKDF2-HMAC-SHA256 record with a random
/// per-credential salt. Records written by older releases (bare SHA-256 hex)
/// still verify and are re-hashed only after a successful verify. Failed
/// attempts are counted across all methods and persisted, so an app restart
/// does not reset the exponential backoff.
class HiddenNotesAuthService {
  static const _pinHashKey = 'hn_auth_pin_hash';
  static const _passwordHashKey = 'hn_auth_password_hash';
  static const _patternHashKey = 'hn_auth_pattern_hash';
  static const _biometricEnabledKey = 'hn_auth_biometric_enabled';
  static const _failuresKey = 'hn_auth_failures';

  static const _recordVersion = 2;
  static const _kdfName = 'pbkdf2-hmac-sha256';
  static const minIterations = 100000;
  static const maxIterations = 2000000;
  static const defaultIterations = 120000;
  static const _saltBytes = 16;
  static const _hashBytes = 32;

  static const freeAttempts = 5;
  static const baseLockout = Duration(seconds: 30);
  static const maxLockout = Duration(minutes: 15);

  final FlutterSecureStorage _storage;
  final LocalAuthentication _localAuth;
  final DateTime Function() _clock;
  final int _iterations;

  HiddenNotesAuthService({
    FlutterSecureStorage? storage,
    LocalAuthentication? localAuth,
    DateTime Function()? clock,
    int iterations = defaultIterations,
  }) : assert(iterations >= minIterations && iterations <= maxIterations),
       _storage = storage ?? const FlutterSecureStorage(),
       _localAuth = localAuth ?? LocalAuthentication(),
       _clock = clock ?? DateTime.now,
       _iterations = iterations;

  // --- Credential records ---

  Future<List<int>> _derive(String value, List<int> salt, int iterations) async {
    final key = await Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: _hashBytes * 8,
    ).deriveKeyFromPassword(password: value, nonce: salt);
    return key.extractBytes();
  }

  Future<String> _newRecord(String value) async {
    final salt = List<int>.generate(
      _saltBytes,
      (_) => Random.secure().nextInt(256),
    );
    final hash = await _derive(value, salt, _iterations);
    return jsonEncode({
      'v': _recordVersion,
      'kdf': _kdfName,
      'iter': _iterations,
      'salt': base64Encode(salt),
      'hash': base64Encode(hash),
    });
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  static final _legacyPattern = RegExp(r'^[0-9a-f]{64}$');

  /// Returns whether [value] matches [stored] and whether [stored] is a
  /// legacy record that should be upgraded.
  Future<({bool ok, bool legacy})> _matches(String value, String stored) async {
    if (_legacyPattern.hasMatch(stored)) {
      final candidate = crypto.sha256.convert(utf8.encode(value)).bytes;
      final expected = [
        for (var i = 0; i < stored.length; i += 2)
          int.parse(stored.substring(i, i + 2), radix: 16),
      ];
      return (ok: _constantTimeEquals(candidate, expected), legacy: true);
    }
    try {
      final record = jsonDecode(stored) as Map<String, dynamic>;
      final iterations = record['iter'];
      if (record['v'] != _recordVersion ||
          record['kdf'] != _kdfName ||
          iterations is! int ||
          iterations < minIterations ||
          iterations > maxIterations) {
        return (ok: false, legacy: false);
      }
      final salt = base64Decode(record['salt'] as String);
      final expected = base64Decode(record['hash'] as String);
      if (salt.length < _saltBytes ||
          salt.length > 64 ||
          expected.length != _hashBytes) {
        return (ok: false, legacy: false);
      }
      final candidate = await _derive(value, salt, iterations);
      return (ok: _constantTimeEquals(candidate, expected), legacy: false);
    } catch (_) {
      return (ok: false, legacy: false);
    }
  }

  Future<bool> _verify(String storageKey, String value) async {
    if (await lockoutRemaining() > Duration.zero) return false;
    final stored = await _storage.read(key: storageKey);
    if (stored == null) return false;

    final result = await _matches(value, stored);
    if (!result.ok) {
      await _recordFailure();
      return false;
    }
    if (result.legacy) {
      // * upgrade only after a successful verify; on a storage failure the
      // * legacy record stays and is upgraded on a later verify
      try {
        await _storage.write(key: storageKey, value: await _newRecord(value));
      } catch (_) {}
    }
    await _resetFailures();
    return true;
  }

  // --- Backoff ---

  Future<({int count, int last, int until})> _readFailures() async {
    try {
      final raw = await _storage.read(key: _failuresKey);
      if (raw == null) return (count: 0, last: 0, until: 0);
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return (
        count: json['count'] as int,
        last: json['last'] as int,
        until: json['until'] as int,
      );
    } catch (_) {
      // * unreadable state fails towards a lockout, not a reset
      final now = _clock().millisecondsSinceEpoch;
      return (
        count: freeAttempts,
        last: now,
        until: now + baseLockout.inMilliseconds,
      );
    }
  }

  static Duration _delayFor(int count) {
    if (count < freeAttempts) return Duration.zero;
    final doublings = min(count - freeAttempts, 20);
    final ms = baseLockout.inMilliseconds * (1 << doublings);
    return Duration(milliseconds: min(ms, maxLockout.inMilliseconds));
  }

  /// Time left before another credential attempt is accepted.
  Future<Duration> lockoutRemaining() async {
    final f = await _readFailures();
    if (f.until <= 0) return Duration.zero;
    final now = _clock().millisecondsSinceEpoch;
    // * a clock moved backwards never shortens the lockout; it restarts it
    final full = f.until - f.last;
    final left = now < f.last ? full : f.until - now;
    return left <= 0 ? Duration.zero : Duration(milliseconds: min(left, full));
  }

  Future<void> _recordFailure() async {
    final f = await _readFailures();
    final count = f.count + 1;
    final now = _clock().millisecondsSinceEpoch;
    final delay = _delayFor(count);
    try {
      await _storage.write(
        key: _failuresKey,
        value: jsonEncode({
          'count': count,
          'last': now,
          'until': delay == Duration.zero ? 0 : now + delay.inMilliseconds,
        }),
      );
    } catch (_) {}
  }

  Future<void> _resetFailures() async {
    try {
      if (await _storage.containsKey(key: _failuresKey)) {
        await _storage.delete(key: _failuresKey);
      }
    } catch (_) {}
  }

  // --- Biometric ---

  Future<bool> isBiometricAvailable() async {
    try {
      return await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> isBiometricEnabled() async {
    final val = await _storage.read(key: _biometricEnabledKey);
    return val == 'true';
  }

  Future<void> setBiometricEnabled(bool enabled) =>
      _storage.write(key: _biometricEnabledKey, value: enabled.toString());

  Future<bool> authenticateWithBiometric() async {
    try {
      if (!await isBiometricAvailable()) return false;
      return await _localAuth.authenticate(
        localizedReason: 'Verify identity to view hidden notes',
      );
    } catch (_) {
      return false;
    }
  }

  // --- PIN ---

  Future<bool> isPinEnabled() => _storage.containsKey(key: _pinHashKey);

  Future<void> setupPin(String pin) async =>
      _storage.write(key: _pinHashKey, value: await _newRecord(pin));

  Future<bool> verifyPin(String pin) => _verify(_pinHashKey, pin);

  Future<void> removePin() => _storage.delete(key: _pinHashKey);

  // --- Pattern ---

  Future<bool> isPatternEnabled() =>
      _storage.containsKey(key: _patternHashKey);

  Future<void> setupPattern(List<int> pattern) async => _storage.write(
    key: _patternHashKey,
    value: await _newRecord(pattern.join(',')),
  );

  Future<bool> verifyPattern(List<int> pattern) =>
      _verify(_patternHashKey, pattern.join(','));

  Future<void> removePattern() => _storage.delete(key: _patternHashKey);

  // --- Password ---

  Future<bool> isPasswordEnabled() =>
      _storage.containsKey(key: _passwordHashKey);

  Future<void> setupPassword(String password) async => _storage.write(
    key: _passwordHashKey,
    value: await _newRecord(password),
  );

  Future<bool> verifyPassword(String password) =>
      _verify(_passwordHashKey, password);

  Future<void> removePassword() => _storage.delete(key: _passwordHashKey);

  // --- General ---

  Future<Set<HiddenNotesAuthMethod>> getEnabledMethods() async {
    final results = await Future.wait<bool>([
      isBiometricEnabled(),
      isPinEnabled(),
      isPatternEnabled(),
      isPasswordEnabled(),
    ]);
    return {
      if (results[0]) HiddenNotesAuthMethod.biometric,
      if (results[1]) HiddenNotesAuthMethod.pin,
      if (results[2]) HiddenNotesAuthMethod.pattern,
      if (results[3]) HiddenNotesAuthMethod.password,
    };
  }
}
