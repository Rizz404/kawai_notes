import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kawai_notes/core/services/encryption_service.dart';
import 'package:kawai_notes/core/services/note_file_service.dart';
import 'package:kawai_notes/di/common_providers.dart';
import 'package:kawai_notes/di/service_providers.dart';
import 'package:kawai_notes/feature/notes/repositories/note_repository.dart';
import 'package:kawai_notes/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/support/objectbox_test_store.dart';

/// End-to-end tests for the Notes home tab: create, edit, and search a note
/// through the real UI (including the flutter_quill rich text editor),
/// verified against both the UI and the underlying database.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<ObjectBoxTestStore> boot(WidgetTester tester) async {
    final testStore = await ObjectBoxTestStore.open();
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          objectBoxServiceProvider.overrideWithValue(testStore.service),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();
    return testStore;
  }

  /// Polls [condition] instead of guessing a fixed delay — the actual save
  /// runs in a microtask outside of Flutter's scheduled-frame tracking, so
  /// `pumpAndSettle` can return before it lands, especially under heavier
  /// device load (e.g. running many integration test files back to back).
  Future<void> waitFor(
    WidgetTester tester,
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (!condition()) {
      if (DateTime.now().isAfter(deadline)) {
        throw TestFailure('Condition not met within $timeout');
      }
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> createNote(WidgetTester tester, String title) async {
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // AppTextField (title) renders a plain TextField; the Quill rich text
    // body is a separate custom editor widget, so `.first` unambiguously
    // targets the title field.
    await tester.enterText(find.byType(TextField).first, title);
    await tester.pumpAndSettle();

    // The checkmark in the app bar pops the route, which triggers the
    // dirty-state save in NoteEditorScreen's PopScope handler.
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
  }

  testWidgets('create a note through the real UI and see it persisted', (
    tester,
  ) async {
    final testStore = await boot(tester);
    addTearDown(testStore.close);

    await createNote(tester, 'Integration test note');

    // Back on the home tab, the new note should be visible.
    expect(find.text('Integration test note'), findsOneWidget);

    // ...and it must actually be in the database, not just in memory.
    final repository = NoteRepository(
      testStore.service,
      NoteFileService(),
      EncryptionService(),
    );
    expect(
      repository.getAllNotes().map((n) => n.title),
      contains('Integration test note'),
    );
  });

  testWidgets('editing an existing note updates it in place, not a duplicate', (
    tester,
  ) async {
    final testStore = await boot(tester);
    addTearDown(testStore.close);

    final repository = NoteRepository(
      testStore.service,
      NoteFileService(),
      EncryptionService(),
    );

    await createNote(tester, 'Original title');
    expect(find.text('Original title'), findsOneWidget);

    // Tapping the note tile reopens the editor in edit mode.
    await tester.tap(find.text('Original title'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Edited title');
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    // Poll the database directly — the authoritative signal for "the save
    // landed" — instead of guessing how long the save's microtask takes.
    await waitFor(
      tester,
      () => repository.getAllNotes().any((n) => n.title == 'Edited title'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Edited title'), findsOneWidget);

    // Exactly one note in the database, with the new title — proves this
    // was an in-place update, not a duplicate.
    expect(repository.getAllNotes(), hasLength(1));
  });

  testWidgets('the home search field filters the note list by title', (
    tester,
  ) async {
    final testStore = await boot(tester);
    addTearDown(testStore.close);

    await createNote(tester, 'Grocery list');
    await createNote(tester, 'Work meeting notes');
    expect(find.text('Grocery list'), findsOneWidget);
    expect(find.text('Work meeting notes'), findsOneWidget);

    // Home only has one TextField once no dialog/editor is open: the search
    // field itself.
    await tester.enterText(find.byType(TextField), 'grocery');
    await tester.pumpAndSettle();

    expect(find.text('Grocery list'), findsOneWidget);
    expect(find.text('Work meeting notes'), findsNothing);
  });
}
