import 'package:flutter_setup_riverpod/core/extensions/logger_extension.dart';

/// Extension untuk mengambil field secara aman dari format JSON dengan penyesuaian tipe data.
extension SafeMap on Map<String, dynamic> {
  /// Mengambil field wajib dan melempar error beserta log jika tidak ditemukan.
  T getField<T>(String key) {
    try {
      final value = this[key];

      if (value == null) {
        logError('Field "$key" is null or missing');
        throw Exception('Field "$key" is null or missing');
      }

      if (T == DateTime) {
        if (value is String) {
          final parsed = DateTime.parse(value);
          return (parsed.isUtc ? parsed.toLocal() : parsed) as T;
        }
        if (value is int) {
          return DateTime.fromMillisecondsSinceEpoch(value) as T;
        }
        if (value is DateTime) {
          return (value.isUtc ? value.toLocal() : value) as T;
        }

        logError(
          'Field "$key" cannot be converted to DateTime\n'
          '   Got: ${value.runtimeType}\n'
          '   Value: $value',
        );
        throw Exception('Field "$key" cannot be converted to DateTime');
      }

      if (T == double) {
        if (value is double) return value as T;
        if (value is int) return value.toDouble() as T;

        logError(
          'Field "$key" cannot be converted to double\n'
          '   Got: ${value.runtimeType}\n'
          '   Value: $value',
        );
        throw Exception('Field "$key" cannot be converted to double');
      }

      if (value is! T) {
        logError(
          'Field "$key" has wrong type\n'
          '   Expected: $T\n'
          '   Got: ${value.runtimeType}\n'
          '   Value: $value',
        );
        throw Exception(
          'Field "$key" has wrong type. Expected $T but got ${value.runtimeType}',
        );
      }

      return value;
    } catch (e) {
      logError(
        'Error at field "$key": $e\n'
        '   📦 Available keys: ${keys.toList()}\n'
        '   🔍 Value: ${this[key]}',
      );
      rethrow;
    }
  }

  /// Mengambil field secara opsional dan mengembalikan null jika tidak ditemukan atau tidak valid.
  T? getFieldOrNull<T>(String key) {
    try {
      final value = this[key];
      if (value == null) return null;

      if (T == DateTime) {
        if (value is String) {
          final parsed = DateTime.parse(value);
          return (parsed.isUtc ? parsed.toLocal() : parsed) as T?;
        }
        if (value is int) {
          return DateTime.fromMillisecondsSinceEpoch(value) as T?;
        }
        if (value is DateTime) {
          return (value.isUtc ? value.toLocal() : value) as T?;
        }

        logData(
          'Field "$key" cannot be converted to DateTime (returning null)\n'
          '   Got: ${value.runtimeType}',
        );
        return null;
      }

      if (T == double) {
        if (value is double) return value as T?;
        if (value is int) return value.toDouble() as T?;

        logData(
          'Field "$key" cannot be converted to double (returning null)\n'
          '   Got: ${value.runtimeType}',
        );
        return null;
      }

      if (value is! T) {
        logData(
          'Field "$key" type mismatch (returning null)\n'
          '   Expected: $T\n'
          '   Got: ${value.runtimeType}',
        );
        return null;
      }

      return value as T?;
    } catch (e) {
      logData('Warning at field "$key": $e');
      return null;
    }
  }
}
