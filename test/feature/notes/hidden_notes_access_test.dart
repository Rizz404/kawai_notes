import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kawai_notes/core/router/app_route.dart';
import 'package:kawai_notes/core/router/app_route_parser.dart';
import 'package:kawai_notes/core/router/app_route_state.dart';
import 'package:kawai_notes/core/router/app_router_delegate.dart';
import 'package:kawai_notes/core/router/app_router_provider.dart';
import 'package:kawai_notes/core/services/encryption_service.dart';
import 'package:kawai_notes/core/services/hidden_notes_auth_service.dart';
import 'package:kawai_notes/di/repository_providers.dart';
import 'package:kawai_notes/di/service_providers.dart';
import 'package:kawai_notes/feature/notes/providers/hidden_notes_session_provider.dart';
import 'package:kawai_notes/feature/notes/repositories/note_repository.dart';
import 'package:kawai_notes/feature/notes/screens/hidden_notes_screen.dart';
import 'package:kawai_notes/feature/notes/widgets/pin_entry_widget.dart';
import 'package:kawai_notes/feature/other/screens/hidden_notes_auth_screen.dart';
import 'package:kawai_notes/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/objectbox_test_store.dart';

class MockEncryptionService extends Mock implements EncryptionService {}

class _BrokenAuthService extends HiddenNotesAuthService {
  @override
  Future<Set<HiddenNotesAuthMethod>> getEnabledMethods() =>
      Future.error(StateError('keystore unavailable'));
}

const _localizations = <LocalizationsDelegate<dynamic>>[
  L10n.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
  FlutterQuillLocalizations.delegate,
];

/// Lets platform-channel futures (secure storage, local_auth) complete, then
/// settles; a bare pumpAndSettle spins forever on the loading indicator.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

/// Like [_settle], but keeps letting real async work (the PBKDF2 derivation
/// runs on a background isolate) finish until [finder] matches or [timeout].
Future<void> _settleUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final watch = Stopwatch()..start();
  while (finder.evaluate().isEmpty && watch.elapsed < timeout) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

AppRoute _route(List<AppRouteBase> routes, String path) =>
    routes.whereType<AppRoute>().firstWhere((r) => r.path == path);

void main() {
  late ObjectBoxTestStore testStore;
  late MockEncryptionService enc;
  late ProviderContainer container;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    testStore = await ObjectBoxTestStore.open();
    enc = MockEncryptionService();
    when(() => enc.encrypt(any())).thenAnswer(
      (i) async => 'enc:${i.positionalArguments[0]}',
    );
    when(() => enc.decrypt(any())).thenAnswer(
      (i) async => (i.positionalArguments[0] as String).replaceFirst('enc:', ''),
    );
    container = ProviderContainer(
      overrides: [
        objectBoxServiceProvider.overrideWithValue(testStore.service),
        encryptionServiceProvider.overrideWithValue(enc),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    testStore.close();
  });

  NoteRepository repo() => container.read(noteRepositoryProvider);

  group('data-layer guard', () {
    test('hidden content cannot be read while the vault is locked', () async {
      final n = await repo().saveNote(
        title: 'S',
        content: 'secret',
        isHidden: true,
      );

      await expectLater(
        repo().getNoteContent(repo().getNote(n.id)!),
        throwsA(isA<HiddenNotesLockedException>()),
      );
      verifyNever(() => enc.decrypt(any()));
    });

    test('hidden content is readable after unlock, relocks on lock', () async {
      final n = await repo().saveNote(
        title: 'S',
        content: 'secret',
        isHidden: true,
      );
      final session = container.read(hiddenNotesSessionProvider.notifier);

      session.unlock();
      expect(await repo().getNoteContent(repo().getNote(n.id)!), 'secret');

      session.lock();
      await expectLater(
        repo().getNoteContent(repo().getNote(n.id)!),
        throwsA(isA<HiddenNotesLockedException>()),
      );
    });

    test('plain notes are readable while locked', () async {
      final n = await repo().saveNote(title: 'P', content: 'open');

      expect(await repo().getNoteContent(repo().getNote(n.id)!), 'open');
    });
  });

  group('route guard', () {
    test('/hidden-notes redirects to the challenge while locked', () async {
      final routes = container.read(routerRoutesProvider);
      final redirect = _route(routes, '/hidden-notes').redirect;

      expect(redirect, isNotNull);
      final target = await redirect!(AppRouteState.fromPath('/hidden-notes'));
      expect(Uri.parse(target!).path, '/hidden-notes-challenge');

      container.read(hiddenNotesSessionProvider.notifier).unlock();
      expect(await redirect(AppRouteState.fromPath('/hidden-notes')), isNull);
    });

    test('/hidden-notes-lock opens directly when no method is configured, so '
        'the first method can be any of PIN, pattern or password', () async {
      final routes = container.read(routerRoutesProvider);
      final redirect = _route(routes, '/hidden-notes-lock').redirect!;

      expect(
        await redirect(AppRouteState.fromPath('/hidden-notes-lock')),
        isNull,
      );
      expect(container.read(hiddenNotesSessionProvider), isFalse);
      // * the vault itself stays guarded
      final vault = _route(routes, '/hidden-notes').redirect!;
      final target = await vault(AppRouteState.fromPath('/hidden-notes'));
      expect(Uri.parse(target!).path, '/hidden-notes-challenge');
    });

    for (final setup in <String, Future<void> Function(HiddenNotesAuthService)>{
      'PIN': (s) => s.setupPin('1234'),
      'pattern': (s) => s.setupPattern([0, 1, 2, 5]),
      'password': (s) => s.setupPassword('pw'),
      'biometric': (s) => s.setBiometricEnabled(true),
    }.entries) {
      test('/hidden-notes-lock is challenged once a ${setup.key} is set',
          () async {
        await setup.value(HiddenNotesAuthService());
        final routes = container.read(routerRoutesProvider);
        final redirect = _route(routes, '/hidden-notes-lock').redirect!;

        final target = await redirect(
          AppRouteState.fromPath('/hidden-notes-lock'),
        );
        expect(Uri.parse(target!).path, '/hidden-notes-challenge');
      });
    }

    test('/hidden-notes-lock fails closed when the methods cannot be read',
        () async {
      final broken = _BrokenAuthService();
      final c = ProviderContainer(
        overrides: [
          objectBoxServiceProvider.overrideWithValue(testStore.service),
          encryptionServiceProvider.overrideWithValue(enc),
          hiddenNotesAuthServiceProvider.overrideWithValue(broken),
        ],
      );
      addTearDown(c.dispose);
      final redirect = _route(
        c.read(routerRoutesProvider),
        '/hidden-notes-lock',
      ).redirect!;

      final target = await redirect(
        AppRouteState.fromPath('/hidden-notes-lock'),
      );
      expect(Uri.parse(target!).path, '/hidden-notes-challenge');
    });

    test('/hidden-notes-lock redirects to the challenge while locked', () async {
      await HiddenNotesAuthService().setupPin('1234');
      final routes = container.read(routerRoutesProvider);
      final redirect = _route(routes, '/hidden-notes-lock').redirect;

      expect(redirect, isNotNull);
      final target = await redirect!(
        AppRouteState.fromPath('/hidden-notes-lock'),
      );
      expect(Uri.parse(target!).path, '/hidden-notes-challenge');
      expect(
        Uri.parse(target).queryParameters['next'],
        '/hidden-notes-lock',
      );
    });

    test('/note-editor for a hidden note id is challenged, plain is not', () async {
      final hidden = await repo().saveNote(
        title: 'H',
        content: 'x',
        isHidden: true,
      );
      final plain = await repo().saveNote(title: 'P', content: 'y');
      final routes = container.read(routerRoutesProvider);
      final redirect = _route(routes, '/note-editor').redirect;

      expect(redirect, isNotNull);
      final hiddenTarget = await redirect!(
        AppRouteState.fromPath('/note-editor', extra: {'id': hidden.id}),
      );
      expect(Uri.parse(hiddenTarget!).path, '/hidden-notes-challenge');
      expect(
        await redirect(
          AppRouteState.fromPath('/note-editor', extra: {'id': plain.id}),
        ),
        isNull,
      );
    });
  });

  group('lock settings require the current credential', () {
    testWidgets('removing the PIN asks for the PIN first', (tester) async {
      final service = HiddenNotesAuthService();
      await tester.runAsync(() => service.setupPin('1234'));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: _localizations,
            builder: BotToastInit(),
            navigatorObservers: [BotToastNavigatorObserver()],
            home: const HiddenNotesAuthScreen(),
          ),
        ),
      );
      await _settle(tester);

      final pinRow = find.ancestor(
        of: find.text('PIN'),
        matching: find.byType(ListTile),
      );
      await tester.tap(
        find.descendant(of: pinRow, matching: find.byType(PopupMenuButton<String>)),
      );
      await _settle(tester);
      await tester.tap(find.text('Remove').last);
      await _settle(tester);

      expect(find.text('Remove PIN?'), findsNothing);
      expect(find.byType(PinEntryWidget), findsOneWidget);

      // * wrong PIN keeps the lock
      for (final d in '9999'.split('')) {
        await tester.tap(find.text(d).last);
        await tester.pump();
      }
      await _settleUntil(tester, find.textContaining('Wrong PIN'));
      expect(find.textContaining('Wrong PIN'), findsOneWidget);
      expect(find.text('Remove PIN?'), findsNothing);
      await tester.tap(find.text('Cancel'));
      await _settle(tester);
      expect(await tester.runAsync(service.isPinEnabled), isTrue);

      // * correct PIN then confirm removes it
      await tester.tap(
        find.descendant(of: pinRow, matching: find.byType(PopupMenuButton<String>)),
      );
      await _settle(tester);
      await tester.tap(find.text('Remove').last);
      await _settle(tester);
      for (final d in '1234'.split('')) {
        await tester.tap(find.text(d).last);
        await tester.pump();
      }
      await _settleUntil(tester, find.text('Remove PIN?'));
      expect(find.text('Remove PIN?'), findsOneWidget);
      await tester.tap(find.text('Remove').last);
      await _settle(tester);
      expect(await tester.runAsync(service.isPinEnabled), isFalse);
      // * let the success toast expire
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });
  });

  group('hidden notes FAB (NEW-7)', () {
    testWidgets('creates an encrypted hidden note', (tester) async {
      container.read(hiddenNotesSessionProvider.notifier).unlock();
      final appRoutes = container.read(routerRoutesProvider);
      final delegate = AppRouterDelegate(
        navigatorKey: GlobalKey<NavigatorState>(),
        routes: [
          AppRoute(
            path: '/',
            builder: (context, state) => const HiddenNotesScreen(),
          ),
          _route(appRoutes, '/note-editor'),
        ],
      );
      addTearDown(delegate.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            localizationsDelegates: _localizations,
            supportedLocales: L10n.supportedLocales,
            routerDelegate: delegate,
            routeInformationParser: const AppRouteParser(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Vault note');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.check));
      await tester.pumpAndSettle();

      final saved = repo().getAllNotes().single;
      expect(saved.title, 'Vault note');
      expect(saved.isHidden, isTrue);
      // * the refreshed vault list now shows the new note
      expect(find.text('Vault note'), findsOneWidget);

      // * unmount and let the preview cache timers expire
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(minutes: 6));
    });
  });
}
