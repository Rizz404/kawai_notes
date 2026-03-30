import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_setup_riverpod/core/constants/storage_key_constant.dart';

import 'package:flutter_setup_riverpod/core/router/app_router_provider.dart';
import 'package:flutter_setup_riverpod/core/themes/app_theme.dart';
import 'package:flutter_setup_riverpod/core/utils/logger.dart';
import 'package:flutter_setup_riverpod/core/utils/talker_config.dart';
import 'package:flutter_setup_riverpod/di/common_providers.dart';
import 'package:flutter_setup_riverpod/l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;

Future<void> main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  // * Uncomment setelah ada splash screen
  // FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  TalkerConfig.initialize();

  try {
    tz.initializeTimeZones();

    // * Pre-cache main font selagi splash screen
    await GoogleFonts.pendingFonts();

    // * Storage
    const secureStorage = FlutterSecureStorage();
    final preferencesWithCache = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(
        allowList: {StorageKeyConstant.userKey},
      ),
    );
    final preferences = await SharedPreferences.getInstance();

    runApp(
      ProviderScope(
        overrides: [
          secureStorageProvider.overrideWithValue(secureStorage),
          sharedPreferencesWithCacheProvider.overrideWithValue(
            preferencesWithCache,
          ),
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        observers: [TalkerConfig.riverpodObserver],
        child: const MyApp(),
      ),
    );
  } catch (e) {
    // * Uncomment setelah ada splash screen
    // FlutterNativeSplash.remove();
    AppLogger.instance.error('Error initializing app', e);

    runApp(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: [
            L10n.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: L10n.supportedLocales,
          home: Scaffold(body: Center(child: Text('Error initializing app'))),
        ),
      ),
    );
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeProvider);
    final routerDelegate = ref.watch(routerDelegateProvider);
    final routeParser = ref.watch(routeParserProvider);
    final botToastBuilder = BotToastInit();

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'My App',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      builder: botToastBuilder,

      // * Router Configuration
      routerDelegate: routerDelegate,
      routeInformationParser: routeParser,
      // * Localization Configuration
      localizationsDelegates: const [
        L10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: L10n.supportedLocales,
      locale: currentLocale,

      // * Locale Resolution Strategy
      localeResolutionCallback: (locale, supportedLocales) {
        // * If device locale is supported, use it
        if (locale != null) {
          for (var supportedLocale in supportedLocales) {
            if (supportedLocale.languageCode == locale.languageCode &&
                supportedLocale.countryCode == locale.countryCode) {
              return supportedLocale;
            }
          }

          // * If exact match not found, try language code only
          for (var supportedLocale in supportedLocales) {
            if (supportedLocale.languageCode == locale.languageCode) {
              return supportedLocale;
            }
          }
        }

        // * Fallback to first supported locale (should be 'en')
        return supportedLocales.first;
      },
    );
  }
}
