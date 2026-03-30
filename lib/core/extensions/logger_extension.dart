import 'package:flutter_setup_riverpod/core/utils/logger.dart';

/// Extension untuk mempermudah akses logger pada setiap object.
extension LoggerExtensions on Object {
  String get _className => runtimeType.toString();

  /// Mencatat pesan info secara general dengan prefix nama class.
  void logInfo(String message) {
    logger.info('[$_className] $message');
  }

  /// Mencatat pesan error beserta object error dan stack trace opsional.
  void logError(String message, [Object? error, StackTrace? stackTrace]) {
    logger.error('[$_className] $message', error, stackTrace);
  }

  /// Mencatat pesan spesifik untuk data layer beserta error dan stack trace opsional.
  void logData(String message, [Object? error, StackTrace? stackTrace]) {
    logger.logData(
      '[$_className] $message',
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Mencatat pesan spesifik untuk domain layer beserta error dan stack trace opsional.
  void logDomain(String message, [Object? error, StackTrace? stackTrace]) {
    logger.logDomain(
      '[$_className] $message',
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Mencatat pesan spesifik untuk presentation layer beserta error dan stack trace opsional.
  void logPresentation(
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    logger.logPresentation(
      '[$_className] $message',
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Mencatat pesan spesifik untuk service layer beserta error dan stack trace opsional.
  void logService(String message, [Object? error, StackTrace? stackTrace]) {
    logger.logService(
      '[$_className] $message',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
