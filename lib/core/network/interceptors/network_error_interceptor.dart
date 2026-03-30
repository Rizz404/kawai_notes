// * Uncomment kalo dibutuhin
/* import 'package:flutter_setup_riverpod/core/extensions/localization_extension.dart';
import 'package:flutter_setup_riverpod/core/extensions/logger_extension.dart';
import 'package:flutter_setup_riverpod/core/utils/toast_utils.dart';
import 'package:flutter_setup_riverpod/l10n/app_localizations.dart';
import 'package:dio/dio.dart';

class NetworkErrorInterceptor extends Interceptor {
  NetworkErrorInterceptor();

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final errorInfo = _categorizeError(err);

    if (errorInfo != null) {
      logError(errorInfo.logMessage, err.message);

      AppToast.serverError(errorInfo.userMessage);
    }

    super.onError(err, handler);
  }

  _ErrorInfo? _categorizeError(DioException err) {
    L10n? l10n;
    try {
      l10n = LocalizationExtension.current;
    } catch (_) {}

    String getMessage(String Function(L10n) localized, String fallback) {
      if (l10n != null) return localized(l10n);
      return fallback;
    }

    if (err.type == DioExceptionType.connectionError) {
      if (err.message?.contains('Failed host lookup') == true) {
        return _ErrorInfo(
          logMessage: 'DNS Failure',
          userMessage: getMessage(
            (l) => l.networkErrorDnsFailureUser,
            'Cannot connect to server',
          ),
        );
      }

      return _ErrorInfo(
        logMessage: 'Connection Error',
        userMessage: getMessage(
          (l) => l.networkErrorConnectionUser,
          'Connection lost',
        ),
      );
    }

    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout) {
      return _ErrorInfo(
        logMessage: 'Connection Timeout',
        userMessage: getMessage(
          (l) => l.networkErrorTimeoutUser,
          'Connection timeout',
        ),
      );
    }

    if (err.type == DioExceptionType.receiveTimeout) {
      return _ErrorInfo(
        logMessage: 'Receive Timeout',
        userMessage: getMessage(
          (l) => l.networkErrorReceiveTimeoutUser,
          'Server took too long to respond',
        ),
      );
    }

    final statusCode = err.response?.statusCode;
    if (statusCode != null && statusCode >= 500 && statusCode < 600) {
      return _ErrorInfo(
        logMessage: 'Server Error ($statusCode)',
        userMessage: _getServerErrorMessage(statusCode, l10n),
      );
    }

    return null;
  }

  String _getServerErrorMessage(int statusCode, L10n? l10n) {
    if (l10n == null) return 'Server Error ($statusCode)';

    switch (statusCode) {
      case 500:
        return l10n.networkErrorServerUser;
      case 502:
        return l10n.networkErrorServer502User;
      case 503:
        return l10n.networkErrorServer503User;
      case 504:
        return l10n.networkErrorServer504User;
      default:
        return l10n.networkErrorServerUser;
    }
  }
}

class _ErrorInfo {
  final String logMessage;
  final String userMessage;

  const _ErrorInfo({required this.logMessage, required this.userMessage});
}
 */
