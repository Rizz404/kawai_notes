import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thrown when hidden-note ciphertext cannot be decrypted (wrong/missing key
/// or corrupt data). Callers must never persist anything in place of the
/// original ciphertext when they catch this.
class DecryptionException implements Exception {
  final Object? cause;

  const DecryptionException([this.cause]);

  @override
  String toString() => 'DecryptionException';
}

/// Thrown when hidden-note content is requested while the hidden-notes
/// vault is locked. Extends [DecryptionException] so every caller that
/// protects ciphertext on decrypt failure also fails closed here.
class HiddenNotesLockedException extends DecryptionException {
  const HiddenNotesLockedException() : super('hidden notes locked');

  @override
  String toString() => 'HiddenNotesLockedException';
}

/// Thrown when a wrapped key file cannot be imported. Nothing is stored.
class KeyImportException implements Exception {
  final String message;

  const KeyImportException(this.message);

  @override
  String toString() => 'KeyImportException: $message';
}

/// Thrown when the key cannot be exported (no key yet, or secure storage
/// is unavailable). Export never creates a key.
class KeyExportException implements Exception {
  final String message;

  const KeyExportException(this.message);

  @override
  String toString() => 'KeyExportException: $message';
}

/// AES-GCM note encryption with a keyring.
///
/// The current key (`kawai_notes_encryption_key`, unchanged since the first
/// release) encrypts new content. Keys imported from other devices are kept
/// in an additional keyring entry, so no key that existing ciphertext needs
/// is ever replaced or dropped. Ciphertext carries no key id; decryption
/// tries each key, and AES-GCM authentication rejects the wrong ones.
class EncryptionService {
  static const _keyKey = 'kawai_notes_encryption_key';
  static const _keyringKey = 'kawai_notes_encryption_keyring';

  static const minKeyFileIterations = 100000;
  static const maxKeyFileIterations = 2000000;
  static const _minSaltBytes = 16;
  static const _maxSaltBytes = 64;
  static const _maxKeyFileChars = 256 * 1024;
  static const _maxWrappedBytes = 64 * 1024;
  static const _maxKeysPerFile = 256;

  final FlutterSecureStorage _storage;
  final AesGcm _algorithm = AesGcm.with256bits();

  // * every key mutation runs through this chain so concurrent first use
  // * and imports cannot race (e.g. two keys created, keyring lost update)
  Future<void> _lock = Future.value();

  Future<_Keys>? _keysFuture;

  EncryptionService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  Future<T> _synchronized<T>(Future<T> Function() action) {
    final result = _lock.then((_) => action());
    _lock = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  Future<_Keys> _loadKeys() async {
    final current = await _storage.read(key: _keyKey);
    final ringRaw = await _storage.read(key: _keyringKey);
    final ring = <String>[];
    if (ringRaw != null) {
      for (final k in jsonDecode(ringRaw) as List<dynamic>) {
        if (k is String && k != current && !ring.contains(k)) ring.add(k);
      }
    }
    return _Keys(current, ring);
  }

  Future<_Keys> _keys() {
    return _keysFuture ??= _loadKeys().catchError((Object e) {
      _keysFuture = null;
      throw e;
    });
  }

  /// Whether a note key exists on this device. Never creates one.
  Future<bool> hasKey() async => (await _keys()).current != null;

  Future<SecretKey> _getOrCreateKey() async {
    final keys = await _keys();
    final current = keys.current;
    if (current != null) return SecretKey(base64Decode(current));
    return _synchronized(() async {
      _keysFuture = null;
      final fresh = await _keys();
      if (fresh.current != null) {
        return SecretKey(base64Decode(fresh.current!));
      }
      final newKey = await _algorithm.newSecretKey();
      final encoded = base64Encode(await newKey.extractBytes());
      await _storage.write(key: _keyKey, value: encoded);
      _keysFuture = Future.value(_Keys(encoded, fresh.ring));
      return newKey;
    });
  }

  Future<String> encrypt(String plaintext) async {
    final key = await _getOrCreateKey();
    final secretBox = await _algorithm.encrypt(
      utf8.encode(plaintext),
      secretKey: key,
    );
    final encryptedBytes = secretBox.concatenation();
    return base64Encode(encryptedBytes);
  }

  /// Decryption never creates a key: a missing key means the ciphertext is
  /// currently unreadable, and generating a new one would hide that.
  Future<String> decrypt(String ciphertext) async {
    try {
      final keys = (await _keys()).all;
      if (keys.isEmpty) {
        throw const DecryptionException('encryption key not found');
      }
      final secretBox = SecretBox.fromConcatenation(
        base64Decode(ciphertext),
        nonceLength: _algorithm.nonceLength,
        macLength: _algorithm.macAlgorithm.macLength,
      );
      Object? lastError;
      for (final key in keys) {
        try {
          final decryptedBytes = await _algorithm.decrypt(
            secretBox,
            secretKey: SecretKey(base64Decode(key)),
          );
          return utf8.decode(decryptedBytes);
        } on SecretBoxAuthenticationError catch (e) {
          lastError = e;
        }
      }
      throw DecryptionException(lastError);
    } on DecryptionException {
      rethrow;
    } catch (e) {
      throw DecryptionException(e);
    }
  }

  static const _wrapFormatV1 = 'kawai-key/1';
  static const _wrapFormat = 'kawai-key/2';

  Future<SecretKey> _deriveWrappingKey(
    String passphrase,
    List<int> salt,
    int iterations,
  ) {
    return Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    ).deriveKeyFromPassword(password: passphrase, nonce: salt);
  }

  /// Exports every note key (current first) encrypted with a
  /// passphrase-derived key (PBKDF2-HMAC-SHA256 + AES-GCM). The plaintext
  /// keys are never written out. Throws [KeyExportException] when there is
  /// no key yet; export never creates one.
  Future<String> exportWrappedKey(
    String passphrase, {
    int iterations = 210000,
  }) async {
    if (passphrase.isEmpty) {
      throw ArgumentError.value(passphrase, 'passphrase', 'must not be empty');
    }
    if (iterations < minKeyFileIterations ||
        iterations > maxKeyFileIterations) {
      throw RangeError.range(
        iterations,
        minKeyFileIterations,
        maxKeyFileIterations,
        'iterations',
      );
    }
    final List<String> keys;
    try {
      keys = (await _keys()).all;
    } catch (e) {
      throw KeyExportException('secure storage unavailable: $e');
    }
    if (keys.isEmpty) {
      throw const KeyExportException('no hidden notes key on this device');
    }
    final salt = SecretKeyData.random(length: 16).bytes;
    final wrapping = await _deriveWrappingKey(passphrase, salt, iterations);
    final box = await _algorithm.encrypt(
      utf8.encode(jsonEncode({'keys': keys})),
      secretKey: wrapping,
    );
    return jsonEncode({
      'format': _wrapFormat,
      'kdf': 'pbkdf2-hmac-sha256',
      'iterations': iterations,
      'salt': base64Encode(salt),
      'data': base64Encode(box.concatenation()),
    });
  }

  /// Adds the keys from a file created by [exportWrappedKey] (or the
  /// single-key `kawai-key/1` format) to the keyring. Existing keys are never
  /// replaced or removed; if the device has no key yet, the first imported
  /// key becomes current. Fails closed with [KeyImportException] on a wrong
  /// passphrase, a malformed file or a storage failure, storing nothing.
  Future<void> importWrappedKey(String wrapped, String passphrase) async {
    final imported = await _unwrap(wrapped, passphrase);
    await _synchronized(() async {
      try {
        _keysFuture = null;
        final keys = await _keys();
        var current = keys.current;
        final ring = List<String>.of(keys.ring);
        for (final k in imported) {
          if (current == null) {
            current = k;
          } else if (k != current && !ring.contains(k)) {
            ring.add(k);
          }
        }
        // * keyring first: if the second write fails nothing is lost
        if (ring.length != keys.ring.length) {
          await _storage.write(key: _keyringKey, value: jsonEncode(ring));
        }
        if (current != keys.current) {
          await _storage.write(key: _keyKey, value: current);
        }
        _keysFuture = Future.value(_Keys(current, ring));
      } catch (e) {
        _keysFuture = null;
        throw KeyImportException('secure storage unavailable: $e');
      }
    });
  }

  Future<List<String>> _unwrap(String wrapped, String passphrase) async {
    final List<int> plain;
    final String format;
    if (wrapped.length > _maxKeyFileChars) {
      throw const KeyImportException('key file too large');
    }
    try {
      final json = jsonDecode(wrapped) as Map<String, dynamic>;
      format = json['format'] as String? ?? '';
      if (format != _wrapFormat && format != _wrapFormatV1) {
        throw const KeyImportException('unsupported key file');
      }
      final iterations = json['iterations'];
      if (iterations is! int ||
          iterations < minKeyFileIterations ||
          iterations > maxKeyFileIterations) {
        throw const KeyImportException('unsupported key file parameters');
      }
      final salt = base64Decode(json['salt'] as String);
      final data = base64Decode(json['data'] as String);
      if (salt.length < _minSaltBytes ||
          salt.length > _maxSaltBytes ||
          data.length > _maxWrappedBytes) {
        throw const KeyImportException('unsupported key file parameters');
      }
      final wrapping = await _deriveWrappingKey(passphrase, salt, iterations);
      plain = await _algorithm.decrypt(
        SecretBox.fromConcatenation(
          data,
          nonceLength: _algorithm.nonceLength,
          macLength: _algorithm.macAlgorithm.macLength,
        ),
        secretKey: wrapping,
      );
    } on KeyImportException {
      rethrow;
    } on SecretBoxAuthenticationError {
      throw const KeyImportException('wrong passphrase');
    } catch (_) {
      throw const KeyImportException('invalid key file');
    }

    final List<List<int>> rawKeys;
    try {
      if (format == _wrapFormatV1) {
        rawKeys = [plain];
      } else {
        final payload = jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
        rawKeys = [
          for (final k in payload['keys'] as List<dynamic>)
            base64Decode(k as String),
        ];
      }
    } catch (_) {
      throw const KeyImportException('invalid key file');
    }
    if (rawKeys.isEmpty ||
        rawKeys.length > _maxKeysPerFile ||
        rawKeys.any((k) => k.length != 32)) {
      throw const KeyImportException('invalid key file');
    }
    return [for (final k in rawKeys) base64Encode(k)];
  }
}

class _Keys {
  final String? current;
  final List<String> ring;

  const _Keys(this.current, this.ring);

  List<String> get all => [?current, ...ring];
}
