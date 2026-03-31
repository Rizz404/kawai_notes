import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class EncryptionService {
  static const _storage = FlutterSecureStorage();
  static const _keyKey = 'kawai_notes_encryption_key';

  final AesGcm _algorithm = AesGcm.with256bits();

  Future<SecretKey> _getOrCreateKey() async {
    final existingKeyStr = await _storage.read(key: _keyKey);
    if (existingKeyStr != null) {
      final keyBytes = base64Decode(existingKeyStr);
      return SecretKey(keyBytes);
    } else {
      final newKey = await _algorithm.newSecretKey();
      final keyBytes = await newKey.extractBytes();
      await _storage.write(key: _keyKey, value: base64Encode(keyBytes));
      return newKey;
    }
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

  Future<String> decrypt(String ciphertext) async {
    final key = await _getOrCreateKey();
    final encryptedBytes = base64Decode(ciphertext);
    final secretBox = SecretBox.fromConcatenation(
      encryptedBytes,
      nonceLength: _algorithm.nonceLength,
      macLength: _algorithm.macAlgorithm.macLength,
    );
    final decryptedBytes = await _algorithm.decrypt(secretBox, secretKey: key);
    return utf8.decode(decryptedBytes);
  }
}
