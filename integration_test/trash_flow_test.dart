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

/// End-to-end test for the delete -> trash -> restore lifecycle: select a
/// note on the home tab, batch-delete it (soft delete), confirm it drops
/// off the home list, then restore it from the Trash screen and confirm it
/// reappears on home — all verified against both the UI and the database.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('delete a note to trash, then restore it back to the note list', (
    tester,
  ) async {
    final testStore = await ObjectBoxTestStore.open();
    addTearDown(testStore.close);
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

    // Create a note.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Trash test note');
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    expect(find.text('Trash test note'), findsOneWidget);

    // Long-press to enter selection mode, then batch-delete (soft delete).
    await tester.longPress(find.text('Trash test note'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete));
    await tester.pumpAndSettle();

    expect(find.text('Trash test note'), findsNothing);
    final repository = NoteRepository(
      testStore.service,
      NoteFileService(),
      EncryptionService(),
    );
    final note = repository.getAllNotes().single;
    expect(note.title, 'Trash test note');
    expect(note.isDeleted, isTrue);

    // Navigate: Settings tab -> Trash screen.
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trash'));
    await tester.pumpAndSettle();
    expect(find.text('Trash test note'), findsOneWidget);

    // Restore via the row's overflow menu.
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();

    expect(find.text('Trash is empty.'), findsOneWidget);
    expect(repository.getNote(note.id)?.isDeleted, isFalse);

    // Trash is a global route (not nested in the tab shell), so the bottom
    // nav is hidden until we pop back out of it.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    // Back on the home tab, the note should be visible again.
    await tester.tap(find.text('My Notes'));
    await tester.pumpAndSettle();
    expect(find.text('Trash test note'), findsOneWidget);
  });
}
