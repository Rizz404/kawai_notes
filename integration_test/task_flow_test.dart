import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kawai_notes/di/common_providers.dart';
import 'package:kawai_notes/di/service_providers.dart';
import 'package:kawai_notes/feature/tasks/repositories/task_repository.dart';
import 'package:kawai_notes/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/support/objectbox_test_store.dart';

/// End-to-end tests that drive the real widget tree (real router, real
/// ObjectBox reads/writes) on-device to exercise the Tasks tab: create,
/// toggle completion, and delete, each verified against both the UI and
/// the underlying database.
///
/// The Notes tab is intentionally not exercised here — its editor embeds
/// flutter_quill, whose rich text screen isn't covered by this flow.
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

  Future<void> createTask(WidgetTester tester, String title) async {
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('New Task'), findsOneWidget);

    // AppTextField renders a FormBuilderTextField, which builds a plain
    // TextField (not TextFormField).
    await tester.enterText(find.byType(TextField).first, title);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save Task'));
    await tester.pumpAndSettle();
  }

  testWidgets('create a task through the real UI and see it persisted', (
    tester,
  ) async {
    final testStore = await boot(tester);
    addTearDown(testStore.close);

    await tester.tap(find.text('Tasks'));
    await tester.pumpAndSettle();

    await createTask(tester, 'Integration test task');

    // Back on the Tasks tab, the new task should be visible.
    expect(find.text('Integration test task'), findsOneWidget);

    // ...and it must actually be in the database, not just in memory.
    final repository = TaskRepository(testStore.service);
    expect(
      repository.getAllTasks().map((t) => t.title),
      contains('Integration test task'),
    );
  });

  testWidgets('toggling the checkbox marks a task completed and moves it tab', (
    tester,
  ) async {
    final testStore = await boot(tester);
    addTearDown(testStore.close);

    await tester.tap(find.text('Tasks'));
    await tester.pumpAndSettle();
    await createTask(tester, 'Buy groceries');

    // Active tab is selected by default — the task starts there.
    expect(find.text('Buy groceries'), findsOneWidget);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    final repository = TaskRepository(testStore.service);
    final saved = repository.getAllTasks().single;
    expect(saved.title, 'Buy groceries');
    expect(saved.isCompleted, isTrue);

    // Switch to the Completed tab — the task should now be listed there.
    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();
    expect(find.text('Buy groceries'), findsOneWidget);
  });

  testWidgets('deleting a task removes it from the list and the database', (
    tester,
  ) async {
    final testStore = await boot(tester);
    addTearDown(testStore.close);

    await tester.tap(find.text('Tasks'));
    await tester.pumpAndSettle();
    await createTask(tester, 'Throwaway task');
    expect(find.text('Throwaway task'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.text('Throwaway task'), findsNothing);
    final repository = TaskRepository(testStore.service);
    expect(repository.getAllTasks(), isEmpty);
  });
}
