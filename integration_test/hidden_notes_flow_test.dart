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

/// End-to-end test for the hidden notes lock: set up a real PIN through
/// Settings (backed by the real FlutterSecureStorage plugin on-device), hide
/// a note from the home tab, unlock the hidden notes vault with that PIN,
/// and confirm the note shows up there — all through the real UI.
///
/// Biometric is intentionally not exercised: it needs enrolled hardware
/// sensors on the emulator, which this suite doesn't assume.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> enterPin(WidgetTester tester, String pin) async {
    for (final digit in pin.split('')) {
      await tester.tap(find.text(digit));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  testWidgets(
    'set up a PIN, hide a note, and unlock the hidden notes vault with it',
    (tester) async {
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

      // --- Set up a PIN via Settings -> Hidden Notes Lock ---
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      // On a short emulator screen this list item renders close enough to
      // the bottom nav bar that a raw tap can land on the nav bar instead
      // (it did — the app briefly switched to the Tasks tab). Scroll it
      // fully into view first so the tap can't collide with the nav bar.
      final hiddenNotesLockTile = find.widgetWithText(
        ListTile,
        'Hidden Notes Lock',
      );
      await tester.ensureVisible(hiddenNotesLockTile);
      await tester.pumpAndSettle();
      await tester.tap(hiddenNotesLockTile);
      await tester.pumpAndSettle();

      final pinRow = find.ancestor(
        of: find.text('PIN'),
        matching: find.byType(ListTile),
      );
      await tester.tap(find.descendant(of: pinRow, matching: find.text('Set up')));
      await tester.pumpAndSettle();
      expect(find.text('Enter new PIN'), findsOneWidget);

      await enterPin(tester, '1234');
      expect(find.text('Confirm PIN'), findsOneWidget);
      await enterPin(tester, '1234');

      // Setup succeeds and returns to the method list with PIN now enabled.
      expect(find.text('Enter new PIN'), findsNothing);
      expect(find.text('Enabled'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      // --- Create and hide a note from the home tab ---
      await tester.tap(find.text('My Notes'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Secret note');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.check));
      await tester.pumpAndSettle();
      expect(find.text('Secret note'), findsOneWidget);

      await tester.longPress(find.text('Secret note'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.visibility_off));
      await tester.pumpAndSettle();

      // Hidden notes are excluded from the regular home list.
      expect(find.text('Secret note'), findsNothing);
      final repository = NoteRepository(
        testStore.service,
        NoteFileService(),
        EncryptionService(),
      );
      expect(repository.getAllNotes().single.isHidden, isTrue);

      // --- Unlock the hidden notes vault with the PIN ---
      await tester.tap(find.byIcon(Icons.lock_outline));
      await tester.pumpAndSettle();
      expect(find.text('Hidden Notes'), findsOneWidget);

      await enterPin(tester, '1234');

      // Landed on the hidden notes screen with the note visible.
      expect(find.text('Secret note'), findsOneWidget);

      // --- Unhide it again ---
      await tester.longPress(find.text('Secret note'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.visibility));
      await tester.pumpAndSettle();

      expect(find.text('Secret note'), findsNothing);
      expect(repository.getAllNotes().single.isHidden, isFalse);
    },
  );
}
