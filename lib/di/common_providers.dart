import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_setup_riverpod/core/enums/language_enum.dart';
import 'package:flutter_setup_riverpod/core/services/language_storage_service.dart';
import 'package:flutter_setup_riverpod/core/services/theme_storage_service.dart';
import 'package:flutter_setup_riverpod/di/service_providers.dart';
import 'package:flutter_setup_riverpod/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  throw UnimplementedError('secureStorageProvider not initialized');
});

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider not initialized');
});

final sharedPreferencesWithCacheProvider = Provider<SharedPreferencesWithCache>(
  (ref) {
    throw UnimplementedError(
      'sharedPreferencesWithCacheProvider not initialized',
    );
  },
);

final dioProvider = Provider<Dio>((ref) {
  return Dio();
});

// * Uncomment kalo dibutuhin
/* final dioClientProvider = Provider<DioClient>((ref) {
  final _dio = ref.watch(dioProvider);
  final _authService = ref.watch(authServiceProvider);
  final dioClient = DioClient(
    _dio,
    _authService,
    onTokenInvalid: () {
      ref.invalidate(authNotifierProvider);
    },
  );

  final currentLocale = ref.watch(localeProvider);
  dioClient.updateLocale(currentLocale);

  return dioClient;
}); */

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(
  LocaleNotifier.new,
);

final themeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(
  ThemeNotifier.new,
);

class LocaleNotifier extends Notifier<Locale> {
  late LanguageStorageService _languageStorageService;

  Locale _getDeviceLocale() {
    final deviceLocale = ui.PlatformDispatcher.instance.locale;
    if (deviceLocale.languageCode == 'ja') {
      return const Locale('ja');
    }
    return const Locale('en');
  }

  @override
  Locale build() {
    _languageStorageService = ref.watch(languageStorageServiceProvider);
    Future.microtask(_loadLocale);
    return _getDeviceLocale();
  }

  Future<void> _loadLocale() async {
    try {
      final locale = await _languageStorageService.getLocale();
      state = locale;
    } catch (e) {
      state = _getDeviceLocale();
    }
  }

  Future<void> changeLocale(Locale newLocale) async {
    try {
      if (L10n.supportedLocales.contains(newLocale)) {
        await _languageStorageService.setLocale(newLocale);
        state = newLocale;
      } else {
        throw ArgumentError('Unsupported locale: $newLocale');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> resetLocale() async {
    try {
      await _languageStorageService.removeLocale();
      state = _getDeviceLocale();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> syncFromUserLanguage(Language language) async {
    try {
      final locale = Locale(language.mobileCode);
      if (L10n.supportedLocales.contains(locale)) {
        await _languageStorageService.setLocale(locale);
        state = locale;
      }
    } catch (e) {
      rethrow;
    }
  }
}

class ThemeNotifier extends Notifier<ThemeMode> {
  late ThemeStorageService _themeStorageService;

  @override
  ThemeMode build() {
    _themeStorageService = ref.watch(themeStorageServiceProvider);
    Future.microtask(_loadThemeMode);
    return ThemeMode.system;
  }

  Future<void> _loadThemeMode() async {
    try {
      final themeMode = await _themeStorageService.getThemeMode();
      state = themeMode;
    } catch (e) {
      state = ThemeMode.system;
    }
  }

  Future<void> changeTheme(ThemeMode newThemeMode) async {
    try {
      await _themeStorageService.setThemeMode(newThemeMode);
      state = newThemeMode;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> resetTheme() async {
    try {
      await _themeStorageService.removeThemeMode();
      state = ThemeMode.system;
    } catch (e) {
      rethrow;
    }
  }
}
