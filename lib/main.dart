import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:bot_toast/bot_toast.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kawai_notes/core/constants/api_constant.dart';
import 'package:kawai_notes/core/constants/storage_key_constant.dart';
import 'package:kawai_notes/core/extensions/localization_extension.dart';
import 'package:kawai_notes/core/extensions/logger_extension.dart';
import 'package:kawai_notes/core/router/app_router_provider.dart';
import 'package:kawai_notes/core/router/widget_deep_link_navigator.dart';
import 'package:kawai_notes/core/services/backup_service.dart';
import 'package:kawai_notes/core/services/encryption_service.dart';
import 'package:kawai_notes/core/services/note_file_service.dart';
import 'package:kawai_notes/core/services/notification_service.dart';
import 'package:kawai_notes/core/services/objectbox_service.dart';
import 'package:kawai_notes/core/services/widget_deep_link_service.dart';
import 'package:kawai_notes/core/themes/app_theme.dart';
import 'package:kawai_notes/core/utils/log_redaction.dart';
import 'package:kawai_notes/core/utils/logger.dart';
import 'package:kawai_notes/core/utils/startup_guard.dart';
import 'package:kawai_notes/core/utils/talker_config.dart';
import 'package:kawai_notes/di/common_providers.dart';
import 'package:kawai_notes/di/repository_providers.dart';
import 'package:kawai_notes/di/service_providers.dart';
import 'package:kawai_notes/feature/notes/providers/hidden_notes_session_provider.dart';
import 'package:kawai_notes/feature/notes/repositories/note_repository.dart';
import 'package:kawai_notes/feature/notes/services/note_widget_service.dart';
import 'package:kawai_notes/l10n/app_localizations.dart';
import 'package:kawai_notes/shared/widgets/app_text.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;

Future<void> main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  TalkerConfig.initialize();

  try {
    tz.initializeTimeZones();
    await dotenv.load(fileName: '.env');

    if (ApiConstant.supabaseUrl.isNotEmpty &&
        ApiConstant.supabaseAnonKey.isNotEmpty) {
      try {
        await Supabase.initialize(
          url: ApiConstant.supabaseUrl,
          anonKey: ApiConstant.supabaseAnonKey,
          // * Nonaktifkan deteksi URI otomatis — kita handle manual via app_links
          authOptions: const FlutterAuthClientOptions(
            authFlowType: AuthFlowType.pkce,
            detectSessionInUri: false,
          ),
        );
      } catch (e) {
        // ! Supabase init failed (project deleted / invalid keys) — app continues
        // ! in offline-only mode. supabaseClientProvider will return null.
        AppLogger.instance.error('Supabase initialization failed — offline mode', e);
      }
    }

    // * Pre-cache main font selagi splash screen
    await precacheWithTimeout(GoogleFonts.pendingFonts);

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

    final notificationService = NotificationService();
    await notificationService.init();

    final backupService = BackupService(
      objectBoxService,
      preferences,
      notificationService,
      supabaseClient: _supabaseClientOrNull(),
    );
    await backupService.runAutoBackup();

    // * Cleanup Trash Notes
    final noteRepo = NoteRepository(
      objectBoxService,
      NoteFileService(),
      EncryptionService(),
    );
    await noteRepo.migrateToSingleStorage();
    final purgedNoteIds = await noteRepo.cleanUpTrashNotes(days: 30);
    try {
      // * widgets of purged notes go back to the configurable placeholder
      await NoteWidgetService.clearWidgetsForNotes(
        prefs: preferences,
        noteIds: purgedNoteIds,
      );
    } catch (e) {
      AppLogger.instance.error('Widget cleanup after trash purge failed', e);
    }

    // * Tangkap initial deep link SEBELUM runApp
    final appLinks = AppLinks();
    final initialUri = await appLinks.getInitialLink();
    Uri? initialWidgetUri;

    if (initialUri != null) {
      AppLogger.instance.logInfo(
        'Initial deep link (cold start): ${redactUriForLog(initialUri)}',
      );
      if (WidgetDeepLinkService.isWidgetUri(initialUri)) {
        // URI dari klik widget — tunda navigasi sampai Flutter tree siap
        initialWidgetUri = initialUri;
      } else {
        await _handleDeepLink(initialUri);
      }
    }

    FlutterNativeSplash.remove();

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
          child: MyApp(initialWidgetUri: initialWidgetUri),
        ),
      ),
    );

    // * Pasang listener foreground SETELAH runApp — tidak ada race condition di sini
    appLinks.uriLinkStream.listen((uri) {
      AppLogger.instance.logInfo('Deep link diterima (foreground): ${redactUriForLog(uri)}');
      if (WidgetDeepLinkService.isWidgetUri(uri)) {
        WidgetDeepLinkService.instance.handle(uri);
      } else {
        _handleDeepLink(uri);
      }
    });
  } catch (e) {
    FlutterNativeSplash.remove();
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

SupabaseClient? _supabaseClientOrNull() {
  try {
    return Supabase.instance.client;
  } catch (_) {
    return null;
  }
}

Future<void> _handleDeepLink(Uri uri) async {
  try {
    final client = Supabase.instance.client;
    // * Supabase akan parse token dari URI dan set session secara otomatis
    await client.auth.getSessionFromUrl(uri);
  } catch (e) {
    AppLogger.instance.error('Gagal handle deep link', e);
  }
}

class MyApp extends ConsumerStatefulWidget {
  final Uri? initialWidgetUri;

  const MyApp({super.key, this.initialWidgetUri});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  StreamSubscription<Uri>? _widgetUriSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Handle URI dari cold start (app dibuka pertama kali dari klik widget)
    if (widget.initialWidgetUri != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateFromWidgetUri(widget.initialWidgetUri!);
      });
    }

    // Handle URI dari foreground (app sudah berjalan, user klik widget)
    _widgetUriSub = WidgetDeepLinkService.instance.stream.listen(
      _navigateFromWidgetUri,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _widgetUriSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // * single lock owner: the vault never stays unlocked while the app is
    // * backgrounded, except briefly for system UI the app opened itself
    ref.read(hiddenNotesSessionProvider.notifier).handleLifecycle(state);
  }

  void _navigateFromWidgetUri(Uri uri) {
    unawaited(
      WidgetDeepLinkNavigator(
        router: ref.read(routerDelegateProvider),
        findNote: ref.read(noteRepositoryProvider).getNote,
      ).open(uri),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          onGenerateTitle: (context) => context.l10n.sharedAppName,
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
            if (locale != null) {
              for (var supportedLocale in supportedLocales) {
                if (supportedLocale.languageCode == locale.languageCode &&
                    supportedLocale.countryCode == locale.countryCode) {
                  return supportedLocale;
                }
              }
              for (var supportedLocale in supportedLocales) {
                if (supportedLocale.languageCode == locale.languageCode) {
                  return supportedLocale;
                }
              }
            }
            return supportedLocales.first;
          },
        );
      },
    );
  }
}
