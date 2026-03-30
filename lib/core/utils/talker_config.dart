import 'package:flutter/foundation.dart';
import 'package:flutter_setup_riverpod/core/utils/logger.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:talker_riverpod_logger/talker_riverpod_logger.dart';

class TalkerConfig {
  static late final Talker talker;

  static void initialize() {
    talker = TalkerFlutter.init(
      settings: TalkerSettings(
        enabled: true,
        useConsoleLogs: kDebugMode,
        maxHistoryItems: kDebugMode ? 1000 : 100,
        useHistory: true,
      ),
      logger: TalkerLogger(
        settings: TalkerLoggerSettings(enableColors: kDebugMode),
      ),
    );

    _logAppStart();
  }

  static TalkerRiverpodObserver get riverpodObserver => TalkerRiverpodObserver(
    talker: AppLogger.instance.talker,
    settings: const TalkerRiverpodLoggerSettings(
      printProviderAdded: true,
      printProviderDisposed: true,
      printProviderUpdated: true,
    ),
  );

  static void _logAppStart() {
    logger.info('My App App Started');
    logger.debug('Environment: ${kDebugMode ? 'DEBUG' : 'RELEASE'}');
    logger.debug('Platform: ${defaultTargetPlatform.name}');
  }

  static void configureForEnvironment(String environment) {
    switch (environment.toLowerCase()) {
      case 'development':
      case 'debug':
        _configureForDebug();
        break;
      case 'staging':
        _configureForStaging();
        break;
      case 'production':
      case 'release':
        _configureForProduction();
        break;
    }
  }

  static void _configureForDebug() {
    talker.configure(
      settings: talker.settings.copyWith(
        useConsoleLogs: true,
        maxHistoryItems: 1000,
        enabled: true,
      ),
    );
    logger.debug('Talker configured for DEBUG environment');
  }

  static void _configureForStaging() {
    talker.configure(
      settings: talker.settings.copyWith(
        useConsoleLogs: true,
        maxHistoryItems: 500,
        enabled: true,
      ),
    );
    logger.debug('Talker configured for STAGING environment');
  }

  static void _configureForProduction() {
    talker.configure(
      settings: talker.settings.copyWith(
        useConsoleLogs: false,
        maxHistoryItems: 100,
        enabled: true,
      ),
    );
    logger.info('Talker configured for PRODUCTION environment');
  }

  static String getFormattedLogs() {
    return logger.exportLogs();
  }

  static void clearAllLogs() {
    logger.clearLogs();
    logger.info('All logs cleared');
  }
}
