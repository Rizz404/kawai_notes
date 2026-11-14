import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kawai_notes/core/services/hidden_notes_auth_service.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mocktail/mocktail.dart';

class _MockLocalAuth extends Mock implements LocalAuthentication {}

/// Measures how much of [work]'s wall time the calling isolate spent busy:
/// a zero-delay timer loop records every gap longer than [slack].
Future<({Duration elapsed, Duration busy})> _measure(
  Future<void> Function() work, {
  Duration slack = const Duration(microseconds: 500),
}) async {
  var busy = Duration.zero;
  var running = true;
  final watch = Stopwatch()..start();
  var last = watch.elapsed;
  void tick() {
    final now = watch.elapsed;
    final gap = now - last;
    if (gap > slack) busy += gap;
    last = now;
    if (running) Timer.run(tick);
  }

  Timer.run(tick);
  await work();
  running = false;
  return (elapsed: watch.elapsed, busy: busy);
}

/// The PBKDF2 derivation (setup, verify, legacy upgrade) must not run on the
/// calling (UI) isolate, and moving it must not change the stored format.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  HiddenNotesAuthService service() => HiddenNotesAuthService(
    localAuth: _MockLocalAuth(),
    iterations: 600000,
  );

  test('setup and verify keep the calling isolate responsive', () async {
    final s = service();

    final setup = await _measure(() => s.setupPin('1234'));
    final verify = await _measure(() async {
      expect(await s.verifyPin('1234'), isTrue);
    });

    for (final r in [setup, verify]) {
      // ignore: avoid_print
      print('calling isolate busy ${r.busy} of ${r.elapsed}');
      expect(
        r.busy.inMicroseconds,
        lessThan(r.elapsed.inMicroseconds * 0.5),
        reason: 'busy ${r.busy} of ${r.elapsed} on the calling isolate',
      );
    }
  });

  test('records stay compatible: a default service verifies them', () async {
    await service().setupPin('2468');
    final other = HiddenNotesAuthService(localAuth: _MockLocalAuth());
    expect(await other.verifyPin('2468'), isTrue);
    expect(await other.verifyPin('2469'), isFalse);
  });
}
