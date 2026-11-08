import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kawai_notes/core/router/app_router_delegate.dart';
import 'package:kawai_notes/core/router/app_router_provider.dart';
import 'package:kawai_notes/core/services/encryption_service.dart';
import 'package:kawai_notes/di/repository_providers.dart';
import 'package:kawai_notes/di/service_providers.dart';
import 'package:kawai_notes/feature/notes/providers/hidden_notes_session_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/objectbox_test_store.dart';

class MockEncryptionService extends Mock implements EncryptionService {}

/// F7: one owner locks the vault; locking removes every vault page (list,
/// lock settings, hidden editors) so cancelling the re-auth leaves the
/// vault entirely; transient system UI started by the app gets a grace.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ObjectBoxTestStore testStore;
  late ProviderContainer container;
  late AppRouterDelegate router;
  late DateTime now;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    testStore = await ObjectBoxTestStore.open();
    now = DateTime.utc(2026, 11, 1, 9);
    final enc = MockEncryptionService();
    when(() => enc.encrypt(any())).thenAnswer(
      (i) async => 'enc:${i.positionalArguments[0]}',
    );
    container = ProviderContainer(
      overrides: [
        objectBoxServiceProvider.overrideWithValue(testStore.service),
        encryptionServiceProvider.overrideWithValue(enc),
        hiddenNotesClockProvider.overrideWithValue(() => now),
      ],
    );
    router = container.read(routerDelegateProvider);
    await pumpEventQueue();
  });

  tearDown(() {
    container.dispose();
    testStore.close();
  });

  HiddenNotesSessionNotifier session() =>
      container.read(hiddenNotesSessionProvider.notifier);
  bool unlocked() => container.read(hiddenNotesSessionProvider);
  Uri location() => router.currentConfiguration.uri;

  List<String> stack() => [
    for (final p in router.globalPages) Uri.parse(p.name ?? '').path,
  ];

  Future<int> hiddenNote() async => (await container
          .read(noteRepositoryProvider)
          .saveNote(title: 'Secret title', content: 'x', isHidden: true))
      .id;

  Future<void> openVaultWithEditor(int id) async {
    session().unlock();
    router.push('/hidden-notes');
    await pumpEventQueue();
    router.push('/note-editor', extra: {'id': id});
    await pumpEventQueue();
    expect(stack(), ['/hidden-notes', '/note-editor']);
  }

  test('pausing locks and removes every vault page', () async {
    final id = await hiddenNote();
    await openVaultWithEditor(id);

    session().handleLifecycle(AppLifecycleState.paused);
    await pumpEventQueue();

    expect(unlocked(), isFalse);
    expect(stack(), isNot(contains('/hidden-notes')));
    expect(stack(), isNot(contains('/note-editor')));
    expect(location().path, hiddenNotesChallengePath);
    expect(
      location().queryParameters['next'],
      '/note-editor?id=$id',
      reason: 'unlocking again resumes the same hidden editor',
    );
  });

  test('cancelling the re-auth leaves the vault with nothing hidden open',
      () async {
    final id = await hiddenNote();
    await openVaultWithEditor(id);
    session().handleLifecycle(AppLifecycleState.paused);
    session().handleLifecycle(AppLifecycleState.resumed);
    await pumpEventQueue();

    router.pop(); // * challenge "Cancel"
    await pumpEventQueue();

    expect(stack(), isEmpty);
    expect(location().path, '/');
    expect(unlocked(), isFalse);
  });

  test('locking outside the vault changes no routes', () async {
    router.push('/backup');
    await pumpEventQueue();

    session().unlock();
    session().lock();
    await pumpEventQueue();

    expect(stack(), ['/backup']);
  });

  test('a plain note editor is not treated as a vault page', () async {
    final plain = await container
        .read(noteRepositoryProvider)
        .saveNote(title: 'Plain', content: 'p');
    session().unlock();
    router.push('/note-editor', extra: {'id': plain.id});
    await pumpEventQueue();

    session().handleLifecycle(AppLifecycleState.paused);
    await pumpEventQueue();

    expect(stack(), ['/note-editor']);
  });

  group('transient system UI grace', () {
    test('a picker started by the app does not lock the vault', () async {
      final id = await hiddenNote();
      await openVaultWithEditor(id);

      await session().runTransient(() async {
        session().handleLifecycle(AppLifecycleState.paused);
        now = now.add(const Duration(seconds: 20));
        session().handleLifecycle(AppLifecycleState.resumed);
      });
      await pumpEventQueue();

      expect(unlocked(), isTrue);
      expect(stack(), ['/hidden-notes', '/note-editor']);
    });

    test('a transient pause longer than the grace still locks', () async {
      final id = await hiddenNote();
      await openVaultWithEditor(id);

      await session().runTransient(() async {
        session().handleLifecycle(AppLifecycleState.paused);
        now = now.add(
          HiddenNotesSessionNotifier.transientGrace +
              const Duration(seconds: 1),
        );
        session().handleLifecycle(AppLifecycleState.resumed);
      });
      await pumpEventQueue();

      expect(unlocked(), isFalse);
      expect(stack(), isNot(contains('/hidden-notes')));
    });

    test('a pause after the transient UI finished locks normally', () async {
      final id = await hiddenNote();
      await openVaultWithEditor(id);
      await session().runTransient(() async {});

      session().handleLifecycle(AppLifecycleState.paused);
      await pumpEventQueue();

      expect(unlocked(), isFalse);
    });

    test('a failing transient action still ends the grace window', () async {
      session().unlock();
      await expectLater(
        session().runTransient<void>(() async => throw StateError('x')),
        throwsStateError,
      );

      session().handleLifecycle(AppLifecycleState.paused);
      expect(unlocked(), isFalse);
    });
  });

  test('detached also locks', () async {
    session().unlock();
    session().handleLifecycle(AppLifecycleState.detached);
    expect(unlocked(), isFalse);
  });
}
