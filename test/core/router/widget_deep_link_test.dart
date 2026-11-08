import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kawai_notes/core/router/app_route.dart';
import 'package:kawai_notes/core/router/app_route_parser.dart';
import 'package:kawai_notes/core/router/app_router_delegate.dart';
import 'package:kawai_notes/core/router/app_router_provider.dart';
import 'package:kawai_notes/core/router/widget_deep_link_navigator.dart';
import 'package:kawai_notes/core/services/encryption_service.dart';
import 'package:kawai_notes/di/repository_providers.dart';
import 'package:kawai_notes/di/service_providers.dart';
import 'package:kawai_notes/feature/notes/providers/hidden_notes_session_provider.dart';
import 'package:kawai_notes/feature/notes/screens/hidden_notes_auth_challenge_screen.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/objectbox_test_store.dart';

class MockEncryptionService extends Mock implements EncryptionService {}

Uri _widgetNote(Object? noteId) => Uri.parse(
  'com.rizz.kawainotes://widget-note?widgetId=7'
  '${noteId == null ? '' : '&noteId=$noteId'}',
);

/// F3 / F12e: widget deep links open the tapped note whether the app is
/// cold, backgrounded or in the foreground; ids are validated; hidden notes
/// stay behind the challenge, which resumes the same editor after unlock.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ObjectBoxTestStore testStore;
  late ProviderContainer container;
  late AppRouterDelegate router;
  late WidgetDeepLinkNavigator navigator;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    testStore = await ObjectBoxTestStore.open();
    final enc = MockEncryptionService();
    when(() => enc.encrypt(any())).thenAnswer(
      (i) async => 'enc:${i.positionalArguments[0]}',
    );
    container = ProviderContainer(
      overrides: [
        objectBoxServiceProvider.overrideWithValue(testStore.service),
        encryptionServiceProvider.overrideWithValue(enc),
      ],
    );
    final routes = container.read(routerRoutesProvider);
    router = AppRouterDelegate(
      navigatorKey: GlobalKey<NavigatorState>(),
      routes: [
        AppRoute(path: '/', builder: (_, _) => const SizedBox()),
        ...routes.whereType<AppRoute>().where((r) => r.path != '/'),
      ],
    );
    navigator = WidgetDeepLinkNavigator(
      router: router,
      findNote: container.read(noteRepositoryProvider).getNote,
    );
    await pumpEventQueue();
  });

  tearDown(() {
    router.dispose();
    container.dispose();
    testStore.close();
  });

  Future<int> note({bool hidden = false, bool deleted = false}) async {
    final repo = container.read(noteRepositoryProvider);
    final n = await repo.saveNote(title: 'N', content: 'c', isHidden: hidden);
    if (deleted) await repo.deleteNote(n.id);
    return n.id;
  }

  Uri location() => router.currentConfiguration.uri;

  test('a widget link opens the editor for that note', () async {
    final id = await note();

    expect(await navigator.open(_widgetNote(id)), isTrue);
    await pumpEventQueue();

    expect(location().path, '/note-editor');
    expect(location().queryParameters['id'], '$id');
  });

  test('the engine route update for the same intent does not reset to home',
      () async {
    final id = await note();
    await navigator.open(_widgetNote(id));
    await pumpEventQueue();

    // * what FlutterActivity pushes for com.rizz.kawainotes://widget-note?..
    // * (empty path + query) when Flutter deep linking is enabled
    final info = RouteInformation(uri: Uri.parse('?widgetId=7&noteId=$id'));
    final parsed = await const AppRouteParser().parseRouteInformation(info);
    await router.setNewRoutePath(parsed);
    final asFullUri = await const AppRouteParser().parseRouteInformation(
      RouteInformation(uri: _widgetNote(id)),
    );
    await router.setNewRoutePath(asFullUri);
    await pumpEventQueue();

    expect(location().path, '/note-editor');
    expect(location().queryParameters['id'], '$id');
  });

  test('repeating the same link (initial + stream) opens one editor', () async {
    final id = await note();

    await navigator.open(_widgetNote(id));
    await pumpEventQueue();
    await navigator.open(_widgetNote(id));
    await pumpEventQueue();

    expect(location().path, '/note-editor');
    router.pop();
    await pumpEventQueue();
    expect(location().path, '/', reason: 'only one editor page was pushed');
  });

  test('invalid, missing, deleted or unknown ids never navigate', () async {
    final deleted = await note(deleted: true);
    for (final id in [
      null,
      'abc',
      '-1',
      '0',
      '1.5',
      '99999999999999999999999',
      '424242',
      deleted,
    ]) {
      expect(await navigator.open(_widgetNote(id)), isFalse, reason: '$id');
      await pumpEventQueue();
      expect(location().path, '/', reason: '$id');
    }
  });

  test('links from another scheme or host are ignored', () async {
    final id = await note();
    for (final uri in [
      Uri.parse('https://evil.example/widget-note?noteId=$id'),
      Uri.parse('com.rizz.kawainotes://login-callback?noteId=$id'),
      Uri.parse('other.app://widget-note?noteId=$id'),
    ]) {
      expect(await navigator.open(uri), isFalse, reason: '$uri');
    }
    expect(location().path, '/');
  });

  test('widget-config links validate the widget id', () async {
    expect(
      await navigator.open(
        Uri.parse('com.rizz.kawainotes://widget-config?widgetId=x'),
      ),
      isFalse,
    );
    expect(
      await navigator.open(
        Uri.parse('com.rizz.kawainotes://widget-config?widgetId=12'),
      ),
      isTrue,
    );
    await pumpEventQueue();
    expect(location().path, '/widget-config');
  });

  group('hidden notes', () {
    test('a locked hidden note goes to the challenge with the editor as next',
        () async {
      final id = await note(hidden: true);

      await navigator.open(_widgetNote(id));
      await pumpEventQueue();

      expect(location().path, hiddenNotesChallengePath);
      final next = location().queryParameters['next']!;
      expect(Uri.parse(next).path, '/note-editor');
      expect(Uri.parse(next).queryParameters['id'], '$id');
      expect(HiddenNotesAuthChallengeScreen.resolveNext(next), next);
    });

    test('after unlock the challenge target opens that hidden editor',
        () async {
      final id = await note(hidden: true);
      await navigator.open(_widgetNote(id));
      await pumpEventQueue();
      final next = HiddenNotesAuthChallengeScreen.resolveNext(
        location().queryParameters['next'],
      );

      container.read(hiddenNotesSessionProvider.notifier).unlock();
      router.replace(next);
      await pumpEventQueue();

      expect(location().path, '/note-editor');
      expect(location().queryParameters['id'], '$id');
    });

    test('an unlocked vault opens the hidden editor directly', () async {
      final id = await note(hidden: true);
      container.read(hiddenNotesSessionProvider.notifier).unlock();

      await navigator.open(_widgetNote(id));
      await pumpEventQueue();

      expect(location().path, '/note-editor');
    });

    test('challenge next only accepts vault routes and editor ids', () {
      const fallback = '/hidden-notes';
      expect(HiddenNotesAuthChallengeScreen.resolveNext(null), fallback);
      expect(
        HiddenNotesAuthChallengeScreen.resolveNext('/hidden-notes-lock'),
        '/hidden-notes-lock',
      );
      expect(
        HiddenNotesAuthChallengeScreen.resolveNext('/note-editor?id=5'),
        '/note-editor?id=5',
      );
      for (final bad in [
        '/backup',
        '/note-editor',
        '/note-editor?id=abc',
        '/note-editor?id=-3',
        '/note-editor?id=5&isHidden=true',
        'https://evil/note-editor?id=5',
      ]) {
        expect(
          HiddenNotesAuthChallengeScreen.resolveNext(bad),
          fallback,
          reason: bad,
        );
      }
    });
  });

  test('the Android manifest hands widget links to app_links only', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(
      manifest,
      matches(
        RegExp(
          r'<meta-data\s+android:name="flutter_deeplinking_enabled"\s+'
          r'android:value="false"\s*/>',
        ),
      ),
    );
  });
}
