import 'package:flutter/foundation.dart';
import 'package:talker_dio_logger/talker_dio_logger.dart';
import 'package:talker_flutter/talker_flutter.dart';

class AppLogger {
  static AppLogger? _instance;
  late final Talker _talker;

  AppLogger._internal() {
    _talker = TalkerFlutter.init(
      settings: TalkerSettings(
        enabled: true,
        useConsoleLogs: kDebugMode,
        maxHistoryItems: 1000,
        useHistory: true,
      ),
      logger: TalkerLogger(settings: TalkerLoggerSettings(enableColors: true)),
    );
  }

  static AppLogger get instance {
    _instance ??= AppLogger._internal();
    return _instance!;
  }

  Talker get talker => _talker;

  void debug(String message, [Object? exception, StackTrace? stackTrace]) {
    _talker.debug(message, exception, stackTrace);
  }

  void info(String message, [Object? exception, StackTrace? stackTrace]) {
    _talker.info(message, exception, stackTrace);
  }

  void warning(String message, [Object? exception, StackTrace? stackTrace]) {
    _talker.warning(message, exception, stackTrace);
  }

  void error(String message, [Object? exception, StackTrace? stackTrace]) {
    _talker.error(message, exception, stackTrace);
  }

  void logData(String message, {Object? error, StackTrace? stackTrace}) {
    if (error != null) {
      _talker.logCustom(
        DataLog(
          message: 'Data: $message',
          error: error,
          stackTrace: stackTrace,
        ),
      );
    } else {
      _talker.logCustom(DataLog(message: 'Data: $message'));
    }
  }

  void logDomain(String message, {Object? error, StackTrace? stackTrace}) {
    if (error != null) {
      _talker.logCustom(
        DomainLog(
          message: 'Domain: $message',
          error: error,
          stackTrace: stackTrace,
        ),
      );
    } else {
      _talker.logCustom(DomainLog(message: 'Domain: $message'));
    }
  }

  void logPresentation(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (error != null) {
      _talker.logCustom(
        PresentationLog(
          message: 'UI: $message',
          error: error,
          stackTrace: stackTrace,
        ),
      );
    } else {
      _talker.logCustom(PresentationLog(message: 'UI: $message'));
    }
  }

  void logService(String message, {Object? error, StackTrace? stackTrace}) {
    if (error != null) {
      _talker.logCustom(
        ServiceLog(
          message: 'Service: $message',
          error: error,
          stackTrace: stackTrace,
        ),
      );
    } else {
      _talker.logCustom(ServiceLog(message: 'Service: $message'));
    }
  }

  TalkerDioLogger get dioLogger => TalkerDioLogger(
    talker: _talker,
    settings: TalkerDioLoggerSettings(
      printRequestHeaders: true,
      printResponseHeaders: false,
      printRequestData: true,
      printResponseData: true,
      printResponseMessage: true,
      responseFilter: (response) {
        final headers = response.headers['content-type'];
        if (headers != null && headers.isNotEmpty) {
          final contentType = headers.first.toLowerCase();

          if (contentType == 'application/pdf' ||
              contentType == 'application/vnd.ms-excel' ||
              contentType ==
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet') {
            return false;
          }
        }
        return true;
      },
    ),
  );

  void clearLogs() {
    _talker.cleanHistory();
  }

  List<TalkerData> getLogs() {
    return _talker.history;
  }

  String exportLogs() {
    return _talker.history
        .map(
          (log) => '${log.displayTime} [${log.logLevel}] ${log.displayMessage}',
        )
        .join('\n');
  }
}

class DataLog extends TalkerLog {
  final Object? logError;
  final StackTrace? _stackTrace;

  DataLog({required String message, Object? error, StackTrace? stackTrace})
    : logError = error,
      _stackTrace = stackTrace,
      super(message);

  @override
  String get title => 'DATA';

  @override
  StackTrace? get stackTrace => _stackTrace;

  @override
  AnsiPen get pen =>
      logError != null ? (AnsiPen()..red()) : (AnsiPen()..xterm(208));
}

class DomainLog extends TalkerLog {
  final Object? logError;
  final StackTrace? _stackTrace;

  DomainLog({required String message, Object? error, StackTrace? stackTrace})
    : logError = error,
      _stackTrace = stackTrace,
      super(message);

  @override
  String get title => 'DOMAIN';

  @override
  StackTrace? get stackTrace => _stackTrace;

  @override
  AnsiPen get pen =>
      logError != null ? (AnsiPen()..red()) : (AnsiPen()..xterm(165));
}

class PresentationLog extends TalkerLog {
  final Object? logError;
  final StackTrace? _stackTrace;

  PresentationLog({
    required String message,
    Object? error,
    StackTrace? stackTrace,
  }) : logError = error,
       _stackTrace = stackTrace,
       super(message);

  @override
  String get title => 'UI';

  @override
  StackTrace? get stackTrace => _stackTrace;

  @override
  AnsiPen get pen =>
      logError != null ? (AnsiPen()..red()) : (AnsiPen()..xterm(81));
}

class ServiceLog extends TalkerLog {
  final Object? logError;
  final StackTrace? _stackTrace;

  ServiceLog({required String message, Object? error, StackTrace? stackTrace})
    : logError = error,
      _stackTrace = stackTrace,
      super(message);

  @override
  String get title => 'SERVICE';

  @override
  StackTrace? get stackTrace => _stackTrace;

  @override
  AnsiPen get pen =>
      logError != null ? (AnsiPen()..red()) : (AnsiPen()..cyan());
}

final logger = AppLogger.instance;
