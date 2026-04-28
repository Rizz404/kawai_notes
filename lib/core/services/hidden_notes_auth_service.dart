import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

enum HiddenNotesAuthMethod { biometric, pin, pattern, password }

class HiddenNotesAuthService {
  static const _pinHashKey = 'hn_auth_pin_hash';
  static const _passwordHashKey = 'hn_auth_password_hash';
  static const _patternHashKey = 'hn_auth_pattern_hash';
  static const _biometricEnabledKey = 'hn_auth_biometric_enabled';

  final FlutterSecureStorage _storage;
  final LocalAuthentication _localAuth;

  HiddenNotesAuthService()
      : _storage = const FlutterSecureStorage(),
        _localAuth = LocalAuthentication();

  String _hash(String value) =>
      sha256.convert(utf8.encode(value)).toString();

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

  Future<void> setupPin(String pin) =>
      _storage.write(key: _pinHashKey, value: _hash(pin));

  Future<bool> verifyPin(String pin) async {
    final stored = await _storage.read(key: _pinHashKey);
    return stored != null && _hash(pin) == stored;
  }

  Future<void> removePin() => _storage.delete(key: _pinHashKey);

  // --- Pattern ---

  Future<bool> isPatternEnabled() =>
      _storage.containsKey(key: _patternHashKey);

  Future<void> setupPattern(List<int> pattern) => _storage.write(
        key: _patternHashKey,
        value: _hash(pattern.join(',')),
      );

  Future<bool> verifyPattern(List<int> pattern) async {
    final stored = await _storage.read(key: _patternHashKey);
    return stored != null && _hash(pattern.join(',')) == stored;
  }

  Future<void> removePattern() => _storage.delete(key: _patternHashKey);

  // --- Password ---

  Future<bool> isPasswordEnabled() =>
      _storage.containsKey(key: _passwordHashKey);

  Future<void> setupPassword(String password) =>
      _storage.write(key: _passwordHashKey, value: _hash(password));

  Future<bool> verifyPassword(String password) async {
    final stored = await _storage.read(key: _passwordHashKey);
    return stored != null && _hash(password) == stored;
  }

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
