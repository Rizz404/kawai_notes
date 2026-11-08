import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kawai_notes/core/router/app_route.dart';
import 'package:kawai_notes/core/router/app_route_parser.dart';
import 'package:kawai_notes/core/router/app_router_delegate.dart';
import 'package:kawai_notes/core/router/app_router_provider.dart';
import 'package:kawai_notes/core/services/encryption_service.dart';
import 'package:kawai_notes/di/repository_providers.dart';
import 'package:kawai_notes/di/service_providers.dart';
import 'package:kawai_notes/feature/notes/screens/home_screen.dart';
import 'package:kawai_notes/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/objectbox_test_store.dart';

class MockEncryptionService extends Mock implements EncryptionService {}

/// Cancelling the colour picker must leave the note's colour untouched
/// (previously the dialog's "cancel" returned the start colour, white,
/// which was then applied).
void main() {
  late ObjectBoxTestStore testStore;
  late ProviderContainer container;
  late int noteId;

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.runAsync(() async {
      testStore = await ObjectBoxTestStore.open();
      container = ProviderContainer(
        overrides: [
          objectBoxServiceProvider.overrideWithValue(testStore.service),
          encryptionServiceProvider.overrideWithValue(MockEncryptionService()),
        ],
      );
      noteId = (await container
              .read(noteRepositoryProvider)
              .saveNote(title: 'Plain', content: 'body'))
          .id;
    });
    addTearDown(() {
      container.dispose();
      testStore.close();
    });
    final appRoutes = container.read(routerRoutesProvider);
    final delegate = AppRouterDelegate(
      navigatorKey: GlobalKey<NavigatorState>(),
      routes: [
        AppRoute(path: '/', builder: (context, state) => const HomeScreen()),
        appRoutes.whereType<AppRoute>().firstWhere(
          (r) => r.path == '/note-editor',
        ),
      ],
    );
    addTearDown(delegate.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          localizationsDelegates: const [
            L10n.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            FlutterQuillLocalizations.delegate,
          ],
          supportedLocales: L10n.supportedLocales,
          routerDelegate: delegate,
          routeInformationParser: const AppRouteParser(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Unmounts the app and lets provider cache timers expire.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 6));
  }

  Future<void> cancelPicker(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.palette_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  }

  testWidgets('batch colour picker cancel is a no-op', (tester) async {
    await pumpApp(tester);

    await tester.longPress(find.text('Plain'));
    await tester.pumpAndSettle();
    await cancelPicker(tester);

    final note = container.read(noteRepositoryProvider).getNote(noteId)!;
    expect(note.colorValue, isNull);
    await unmount(tester);
  });

  testWidgets('editor colour picker cancel is a no-op', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Plain'));
    await tester.pumpAndSettle();
    await cancelPicker(tester);
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );

    final note = container.read(noteRepositoryProvider).getNote(noteId)!;
    expect(note.colorValue, isNull);
    await unmount(tester);
  });
}
