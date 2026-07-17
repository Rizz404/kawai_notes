import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kawai_notes/di/common_providers.dart';
import 'package:kawai_notes/di/service_providers.dart';
import 'package:kawai_notes/feature/folders/repositories/folder_repository.dart';
import 'package:kawai_notes/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/support/objectbox_test_store.dart';

/// End-to-end tests for the folder drawer: create and delete a folder
/// through the real UI (app bar icon -> end drawer -> dialog), verified
/// against both the UI and the underlying database.
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

  Future<void> openDrawerAndCreateFolder(WidgetTester tester, String name) async {
    // Home tab's app bar has a folder icon that opens the end drawer.
    await tester.tap(find.byIcon(Icons.folder_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create New Folder'));
    await tester.pumpAndSettle();

    // Scope to the dialog — the home screen's search field is also a
    // TextField and would otherwise make this finder ambiguous.
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      name,
    );
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
  }

  testWidgets('create a folder through the real UI and see it persisted', (
    tester,
  ) async {
    final testStore = await boot(tester);
    addTearDown(testStore.close);

    await openDrawerAndCreateFolder(tester, 'Integration test folder');

    // The create dialog's Navigator.pop only closes the dialog — the end
    // drawer underneath stays open, now showing the new folder in its list.
    expect(find.text('Integration test folder'), findsOneWidget);

    // ...and it must actually be in the database, not just in memory.
    final repository = FolderRepository(testStore.service);
    expect(
      repository.getAllFolders().map((f) => f.name),
      contains('Integration test folder'),
    );
  });

  testWidgets('deleting a folder removes it from the drawer and the database', (
    tester,
  ) async {
    final testStore = await boot(tester);
    addTearDown(testStore.close);

    await openDrawerAndCreateFolder(tester, 'Throwaway folder');
    expect(find.text('Throwaway folder'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.text('Throwaway folder'), findsNothing);
    final repository = FolderRepository(testStore.service);
    expect(repository.getAllFolders(), isEmpty);
  });
}
