import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kawai_notes/core/services/encryption_service.dart';
import 'package:kawai_notes/core/services/note_file_service.dart';
import 'package:kawai_notes/core/services/widget_deep_link_service.dart';
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

  /// PINs go through a salted PBKDF2 hash that runs asynchronously and can
  /// outlast pumpAndSettle on a slow emulator; poll for the expected UI.
  Future<void> pumpUntil(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final end = DateTime.now().add(timeout);
    while (finder.evaluate().isEmpty && DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
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

      // F6: with no credential yet, the challenge guarding this screen asks
      // for a PIN to be set up instead of silently letting the user in.
      expect(find.text('Set up a PIN to protect hidden notes'), findsOneWidget);
      await enterPin(tester, '1234');
      await pumpUntil(tester, find.text('Confirm your new PIN'));
      await enterPin(tester, '1234');
      await pumpUntil(tester, find.text('Enabled'));

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

      // --- F4: a widget deep link to the hidden id must hit the challenge ---
      final hiddenId = repository.getAllNotes().single.id;
      WidgetDeepLinkService.instance.handle(
        Uri.parse('com.rizz.kawainotes://widget-note?noteId=$hiddenId'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Verify Identity'), findsOneWidget);
      expect(find.text('Secret note'), findsNothing);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // --- Unlock the hidden notes vault with the PIN ---
      await tester.tap(find.byIcon(Icons.lock_outline));
      await tester.pumpAndSettle();
      expect(find.text('Hidden Notes'), findsOneWidget);

      await enterPin(tester, '1234');
      await pumpUntil(tester, find.text('Secret note'));

      // Landed on the hidden notes screen with the note visible.
      expect(find.text('Secret note'), findsOneWidget);

      // --- Unhide it again ---
      await tester.longPress(find.text('Secret note'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.visibility));
      await tester.pumpAndSettle();

      expect(find.text('Secret note'), findsNothing);
      expect(repository.getAllNotes().single.isHidden, isFalse);

      // --- NEW-7: the hidden-list FAB creates a hidden note ---
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Vault note');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.check));
      await tester.pumpAndSettle();
      final vault = repository.getAllNotes().where(
        (n) => n.title == 'Vault note',
      );
      expect(vault.single.isHidden, isTrue);
    },
  );
}
