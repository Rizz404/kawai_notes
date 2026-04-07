import 'package:bot_toast/bot_toast.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_setup_riverpod/shared/widgets/app_text.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_setup_riverpod/core/constants/storage_key_constant.dart';
import 'package:flutter_setup_riverpod/core/router/app_router_provider.dart';
import 'package:flutter_setup_riverpod/core/services/notification_service.dart';
import 'package:flutter_setup_riverpod/core/services/objectbox_service.dart';
import 'package:flutter_setup_riverpod/core/services/backup_service.dart';
import 'package:flutter_setup_riverpod/core/themes/app_theme.dart';
import 'package:flutter_setup_riverpod/core/utils/logger.dart';
import 'package:flutter_setup_riverpod/core/utils/talker_config.dart';
import 'package:flutter_setup_riverpod/di/common_providers.dart';
import 'package:flutter_setup_riverpod/di/service_providers.dart';
import 'package:flutter_setup_riverpod/core/services/encryption_service.dart';
import 'package:flutter_setup_riverpod/core/services/note_file_service.dart';
import 'package:flutter_setup_riverpod/core/extensions/localization_extension.dart';
import 'package:flutter_setup_riverpod/feature/notes/repositories/note_repository.dart';
import 'package:flutter_setup_riverpod/l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

    // * Local DB
    final objectBoxService = await ObjectBoxService.create();

    final backupService = BackupService(objectBoxService, preferences);
    backupService.runAutoBackup();

    // * Cleanup Trash Notes
    final noteRepo = NoteRepository(
      objectBoxService,
      NoteFileService(),
      EncryptionService(),
    );
    await noteRepo.cleanUpTrashNotes(days: 30);

    final notificationService = NotificationService();
    await notificationService.init();

    runApp(
      Phoenix(
        child: ProviderScope(
          overrides: [
            secureStorageProvider.overrideWithValue(secureStorage),
            sharedPreferencesWithCacheProvider.overrideWithValue(
              preferencesWithCache,
            ),
            sharedPreferencesProvider.overrideWithValue(preferences),
            objectBoxServiceProvider.overrideWithValue(objectBoxService),
            notificationServiceProvider.overrideWithValue(notificationService),
          ],
          observers: [TalkerConfig.riverpodObserver],
          child: const MyApp(),
        ),
      ),
    );
  } catch (e) {
    // * Uncomment setelah ada splash screen
    // FlutterNativeSplash.remove();
    AppLogger.instance.error('Error initializing app', e);

    runApp(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: const [
            L10n.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            FlutterQuillLocalizations.delegate,
          ],
          supportedLocales: L10n.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: AppText(context.l10n.sharedErrorInitializingApp),
              ),
            ),
          ),
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
    final isMaterialYouEnabled = ref.watch(materialYouProvider);
    final routerDelegate = ref.watch(routerDelegateProvider);
    final routeParser = ref.watch(routeParserProvider);
    final botToastBuilder = BotToastInit();

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        ThemeData lightTheme = AppTheme.lightTheme;
        ThemeData darkTheme = AppTheme.darkTheme;

        if (isMaterialYouEnabled &&
            lightDynamic != null &&
            darkDynamic != null) {
          lightTheme = AppTheme.lightTheme.copyWith(
            colorScheme: lightDynamic.harmonized(),
          );
          darkTheme = AppTheme.darkTheme.copyWith(
            colorScheme: darkDynamic.harmonized(),
          );
        }

        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          title: 'My App',
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeMode,
          builder: botToastBuilder,

          // * Router Configuration
          backButtonDispatcher: RootBackButtonDispatcher(),
          routerDelegate: routerDelegate,
          routeInformationParser: routeParser,
          // * Localization Configuration
          localizationsDelegates: const [
            L10n.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            FlutterQuillLocalizations.delegate,
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
      },
    );
  }
}
