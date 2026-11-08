import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kawai_notes/core/services/hidden_notes_auth_service.dart';
import 'package:kawai_notes/di/service_providers.dart';
import 'package:kawai_notes/feature/notes/widgets/hidden_notes_auth_body.dart';
import 'package:kawai_notes/feature/notes/widgets/pin_entry_widget.dart';

/// Lets secure-storage futures and the PBKDF2 derivation (which yields via
/// short timers under the fake clock) run to completion.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 150; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
    await tester.pump(const Duration(milliseconds: 5));
  }
}

Future<void> _enterPin(WidgetTester tester, String pin) async {
  for (final d in pin.split('')) {
    await tester.tap(find.text(d).last);
    await tester.pump();
  }
  await _settle(tester);
}

/// F6: with no credential configured the auth body never auto-succeeds; it
/// requires explicit setup, which remains possible (no lock-out).
void main() {
  late Map<String, String> secure;
  late DateTime now;
  late HiddenNotesAuthService service;
  late int successes;
  late int cancels;

  setUp(() {
    secure = <String, String>{};
    FlutterSecureStorage.setMockInitialValues(secure);
    now = DateTime.utc(2026, 11, 1);
    service = HiddenNotesAuthService(clock: () => now);
    successes = 0;
    cancels = 0;
  });

  Future<void> pumpBody(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [hiddenNotesAuthServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          home: Scaffold(
            body: HiddenNotesAuthBody(
              onSuccess: () => successes++,
              onCancel: () => cancels++,
            ),
          ),
        ),
      ),
    );
    await _settle(tester);
  }

  testWidgets('no credential: does not succeed, asks to set up a PIN', (
    tester,
  ) async {
    await pumpBody(tester);

    expect(successes, 0);
    expect(find.textContaining('Set up a PIN'), findsOneWidget);
    expect(find.byType(PinEntryWidget), findsOneWidget);
  });

  testWidgets('explicit setup stores a PIN and then succeeds once', (
    tester,
  ) async {
    await pumpBody(tester);

    await _enterPin(tester, '2468');
    expect(successes, 0);
    expect(find.textContaining('Confirm'), findsOneWidget);
    await _enterPin(tester, '2468');

    expect(successes, 1);
    expect(await tester.runAsync(service.isPinEnabled), isTrue);
    expect(await tester.runAsync(() => service.verifyPin('2468')), isTrue);
  });

  testWidgets('a mismatched confirmation stores nothing', (tester) async {
    await pumpBody(tester);

    await _enterPin(tester, '2468');
    await _enterPin(tester, '1357');

    expect(successes, 0);
    expect(await tester.runAsync(service.isPinEnabled), isFalse);
  });

  testWidgets('cancel during setup reports cancel, not success', (
    tester,
  ) async {
    await pumpBody(tester);

    await tester.tap(find.text('Cancel'));
    await tester.pump();

    expect(cancels, 1);
    expect(successes, 0);
  });

  testWidgets('an active lockout is shown instead of accepting the PIN', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await service.setupPin('1234');
      for (var i = 0; i < HiddenNotesAuthService.freeAttempts; i++) {
        await service.verifyPin('0000');
      }
    });
    await pumpBody(tester);

    await _enterPin(tester, '1234');

    expect(successes, 0);
    expect(find.textContaining('Too many attempts'), findsOneWidget);
  });
}
